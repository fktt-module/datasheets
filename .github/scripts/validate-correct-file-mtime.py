#!/usr/bin/env python3
# -*- coding: utf8 -*-
"""
Changes/updates the modification time (mtime) of files in work tree, based on
the date of the most recent commit that modified the file, if and only if that
time is newer than the mtime of a given reference file, including renames.
---
Useful only in combination with git-store-meta (see git-store-meta.pl) as the
filelist, used for checking all the file mtimes, is build from the
.git_store_meta file.

When the reference file also holds date time information, each file in worktree
especially in a github pipeline with a date that is similar to the date when
the file was actually last modified, assuming the actual modification date and
its commit date are close.

Based and inspired by "git-restore-mtime" from
(https://github.com/MestreLion/git-tools/tree/main)
"""

# TODO:
# - Add -z on git whatchanged/ls-files, so we don't deal with filename decoding
# - When Python is bumped to 3.7, use text instead of universal_newlines on
#   subprocess

if __name__ != "__main__":
    raise ImportError("{} should not be used as a module.".format(__name__))

import argparse
from dateutil import parser
import logging
import os.path
import pathlib
import shlex
import signal
import subprocess
import sys
import time
from typing import Union, Generator, Any
# noinspection PyPep8Naming
import xml.etree.ElementTree as ET

__version__ = "2026.01"

# Update symlinks only if the platform supports not following them
UPDATE_SYMLINKS = bool(os.utime in getattr(os, 'supports_follow_symlinks', []))

# Call os.path.normpath() only if not in a POSIX platform (Windows)
NORMALIZE_PATHS = (os.path.sep != '/')

# (Extra) keywords for the os.utime() call performed by touch()
UTIME_KWS = {} if not UPDATE_SYMLINKS else {'follow_symlinks': False}

# Date format string
ISO8601_UTC_FMT = "%Y-%m-%dT%H:%M:%SZ"


# Command-line interface ######################################################

def parse_args():
    _parser = argparse.ArgumentParser(
        description=__doc__.split('\n---')[0])

    group = _parser.add_mutually_exclusive_group()
    group.add_argument(
        '--quiet', '-q', dest='loglevel',
        action="store_const", const=logging.WARNING, default=logging.INFO,
        help="Suppress informative messages and summary statistics.")
    group.add_argument('--verbose', '-v', action="count", help="""
        Print additional information for each processed file.
        Specify twice to further increase verbosity.
        """)

    _parser.add_argument(
        '--meta-file', '-m', default=".git_store_meta",
        metavar="META_FILE_NAME", help="""
        File containing meta data information for each file in git directory.
        Default: '%(default)s'.                
        """)

    _parser.add_argument(
        '--test', '-t', default=False, action="store_true",
        help="Test run: do not actually update any file timestamp.")

    _parser.add_argument(
        '--commit-time', '-c', dest='commit_time', default=False,
        action='store_true', help="Use commit time instead of author time.")

    _parser.add_argument(
        '--version', '-V', action='version',
        version='%(prog)s version {version}'.format(version=__version__))

    _parser.add_argument(
        '--reference-file', '-r', required=True,
        metavar="REFERENCE_FILE_NAME", help="""
        File used to determine all commits newer then the last change of this
        file.""")

    args_ = _parser.parse_args()
    if args_.verbose:
        # noinspection PyUnresolvedReferences
        args_.loglevel = max(logging.TRACE, logging.DEBUG // args_.verbose)
    args_.debug = args_.loglevel <= logging.DEBUG
    return args_


# Helper functions ############################################################

def setup_logging():
    """Add TRACE logging level and corresponding method
       return the root logger"""
    logging.TRACE = TRACE = logging.DEBUG // 2
    logging.Logger.trace = lambda _, m, *a, **k: _.log(TRACE, m, *a, **k)
    return logging.getLogger()


def normalize(path):
    r"""Normalize paths from git, handling non-ASCII characters.

    Git stores paths as UTF-8 normalization form C.
    If path contains non-ASCII or non-printable characters, git outputs the
    UTF-8 in octal-escaped notation, escaping double-quotes and backslashes,
    and then double-quoting the whole path.
    https://git-scm.com/docs/git-config#Documentation/git-config.txt-corequotePath

    This function reverts this encoding, so:
    normalize(r'"Back\\slash_double\"quote_a\303\247a\303\255"') =>
        r'Back\slash_double"quote_açaí')

    Paths with invalid UTF-8 encoding, such as single 0x80-0xFF bytes (e.g,
    from Latin1/Windows-1251 encoding) are decoded using surrogate escape, the
    same method used by Python for filesystem paths. So 0xE6 ("æ" in Latin1,
    r'\\346' from Git) is decoded as "\udce6".
    See https://peps.python.org/pep-0383/ and
    https://vstinner.github.io/painful-history-python-filesystem-encoding.html

    Also see notes on `windows/non-ascii-paths.txt` about path encodings on
    non-UTF-8 platforms and filesystems.
    """
    if path and path[0] == '"':
        # Python 2: path = path[1:-1].decode("string-escape")
        # Python 3: https://stackoverflow.com/a/46650050/624066
        path = (path[1:-1]                 # Remove enclosing double quotes
                .encode('latin1')          # Convert to bytes, required by 'unicode-escape'
                .decode('unicode-escape')  # Perform the actual octal-escaping decode
                .encode('latin1')          # 1:1 mapping to bytes, UTF-8 encoded
                .decode('utf8', 'surrogateescape'))  # Decode from UTF-8
    if NORMALIZE_PATHS:
        # Make sure the slash matches the OS; for Windows we need a backslash
        path = os.path.normpath(path)
    return path


def dummy(*_args, **_kwargs):
    """No-op function used in dry-run tests"""


def touch(path, mtime):
    """The actual mtime update"""
    os.utime(path, (mtime, mtime), **UTIME_KWS)


def isodate(secs: int):
    # time.localtime() accepts floats, but discards fractional part
    return time.strftime(ISO8601_UTC_FMT, time.gmtime(secs))


def get_mtime_meta(meta_value):
    return int(parser.parse(meta_value).timestamp())


def parse_meta(meta_file) -> list:
    filelist = []
    with open(meta_file, "r", encoding="UTF-8") as file:
        fields = {}
        f_index = -1
        m_index = -1
        for line in file.read().splitlines():
            line = line.strip()
            if line[0] == '#':
                continue
            if line[0] == '<' and line[-1] == '>':
                # this is the line where git_store_meta puts the
                # information about the used fields in the file
                for fi, fv in enumerate(line.split("\t")):
                    fields[fv.strip()[1:-1]] = fi
                # all field values must have a useful index
                assert all(fv > -1 for fv in fields.values())
                # file and mtime are the keys we are using
                assert "file" in fields.keys() and "mtime" in fields.keys()
                # and we need at least file and mtime indices
                f_index = fields["file"]
                m_index = fields["mtime"]
                continue
            _l = line.split("\t")
            if os.path.exists(_l[f_index]) and os.path.isfile(_l[f_index]):
                filelist.append(tuple([_l[f_index], _l[m_index]]))
    return filelist


def get_reference_latest_commit_time(
        git, filelist, reference_file) -> Union[str, None]:
    reference_file_last_change = None
    if not filelist:
        return reference_file_last_change
    mtime = 0
    datestr = isodate(0)

    for line in git.log(max_count=1, commit_time=args.commit_time,
                        paths=[reference_file]):
        # Blank line between Date and list of files
        if not line:
            continue

        # Date line
        if line[0] != ':':  # Faster than `not line.startswith(':')`
            mtime = int(line)
            datestr = isodate(mtime)
            continue

        # File line: three tokens if it describes a renaming, otherwise two
        file = line.split('\t')[-1]
        assert file == reference_file

        meta = [tpl for tpl in filelist if tpl[0] == reference_file][0]
        meta_mtime = get_mtime_meta(meta[1])
        # noinspection PyUnresolvedReferences
        log.trace(f"Data for reference file '{file}':")
        # noinspection PyUnresolvedReferences
        log.trace(f"     commit: {datestr} ({mtime})")
        # noinspection PyUnresolvedReferences
        log.trace(f"  meta file: {meta[1]} ({meta_mtime})")
        reference_file_last_change = datestr
    git.terminate()
    return reference_file_last_change


def is_track_map_file(file_name: str) -> bool:
    valid_extensions = {'.jpeg', 'jpg', '.png', 'gif', '.bmp', '.svg'}
    return any(file_name.lower().endswith(ext) for ext in valid_extensions)


def get_datasheets_with_ref_of(track_map_file) -> Generator[str, Any, None]:
    _tmf = pathlib.Path(track_map_file)
    for _ds in pathlib.Path(_tmf.parent).glob(_tmf.stem + "*.xml"):
        # check if track map file is part of the station datasheet
        root = ET.parse(_ds).getroot()
        if root.find('./plan').attrib['src'] == track_map_file:
            yield _ds.name

# Git class and check_files(), the heart of the script ########################


class Git:
    def __init__(self, errors=True):
        self.gitcmd = ['git']
        self.errors = errors
        self._proc = None
        self.workdir, self.gitdir = self._get_repo_dirs()

    def log(self, commit_time=False, max_count: int = None,
            since: str = None, paths: list = None):
        # log --raw --no-merges is equivalent to whatchanged
        cmd = 'log --raw --no-merges --pretty={}'.format(
            '%ct' if commit_time else '%at')
        if max_count and max_count > 0:
            cmd += f' --max-count={max_count}'
        if since:
            cmd += f' --since={since}'
        return self._run(cmd, paths)

    def terminate(self):
        if self._proc is None:
            return
        try:
            self._proc.terminate()
        except OSError:
            # Avoid errors on OpenBSD
            pass

    def _get_repo_dirs(self):
        return (os.path.normpath(_) for _ in
                self._run(
                    'rev-parse --show-toplevel --absolute-git-dir',
                    check=True))

    def _run(self, cmdstr: str, paths: list = None, output=True, check=False):
        cmdlist = self.gitcmd + shlex.split(cmdstr)
        if paths:
            cmdlist.append('--')
            cmdlist.extend(paths)
        popen_args = dict(universal_newlines=True, encoding='utf8')
        if not self.errors:
            popen_args['stderr'] = subprocess.DEVNULL
        # noinspection PyUnresolvedReferences
        log.trace("Executing: %s", ' '.join(cmdlist))
        if not output:
            return subprocess.call(cmdlist, **popen_args)
        if check:
            try:
                stdout: str = subprocess.check_output(cmdlist, **popen_args)
                return stdout.splitlines()
            except subprocess.CalledProcessError as e:
                raise self.Error(e.returncode, e.cmd, e.output, e.stderr)
        self._proc = subprocess.Popen(cmdlist, stdout=subprocess.PIPE,
                                      **popen_args)
        return (_.rstrip() for _ in self._proc.stdout)

    def __del__(self):
        self.terminate()

    class Error(subprocess.CalledProcessError):
        """Error from git executable"""


def check_files(git, filelist, reference_file_last_change, stats) -> None:
    mtime = 0
    datestr = isodate(0)
    for line in git.log(since=reference_file_last_change,
                        commit_time=args.commit_time):
        stats['loglines'] += 1
        # Blank line between Date and list of files
        if not line:
            continue

        # Date line
        if line[0] != ':':  # Faster than `not line.startswith(':')`
            stats['commits'] += 1
            mtime = int(line)
            datestr = isodate(mtime)
            continue

        # File line: three tokens if it describes a renaming, otherwise two
        tokens = line.split('\t')
        # Possible statuses:
        # M: Modified (content changed)
        # A: Added (created)
        # D: Deleted
        # T: Type changed: to/from regular file, symlinks, submodules
        # R099: Renamed (moved), with % of unchanged content. 100 = pure rename
        # Not possible in log: C=Copied, U=Unmerged, X=Unknown, B=pairing Broken
        status = tokens[0].split(' ')[-1]
        file = tokens[-1]

        # do not any action if file has been deleted
        if status == 'D':
            continue

        meta = [tpl for tpl in filelist if tpl[0] == file]
        if len(meta) > 0:
            meta = meta[0]
            filelist.remove(meta)
            meta_mtime = get_mtime_meta(meta[1])
            log.debug(f"       file: {file}")
            log.debug(f"     commit: {datestr} ({mtime})")
            log.debug(f"  meta file: {meta[1]} ({meta_mtime})")
            if meta_mtime < mtime:
                stats['files'] -= 1
                log.debug(f"   touch to: {datestr}")
                try:
                    touch(os.path.join(git.workdir, normalize(file)), mtime)
                    stats['touches'] += 1
                except Exception as e:
                    log.error("ERROR: %s: %s", e, file)
                    stats['errors'] += 1
                if is_track_map_file(file):
                    # if track map is changed, then the datasheet file is also
                    # changed
                    for ds in get_datasheets_with_ref_of(os.path.join(
                            git.workdir, normalize(file))):
                        try:
                            touch(os.path.join(git.workdir, normalize(ds)),
                                  mtime)
                            stats['touches'] += 1
                        except Exception as e:
                            log.error("ERROR: %s: %s", e, ds)
                            stats['errors'] += 1
    git.terminate()
    stats['skip'] += len(filelist)
    filelist.clear()
    stats['files'] = len(filelist)
    return


# Main Logic ##################################################################

def main():
    start = time.time()  # yes, Wall time. CPU time is not realistic for users.
    stats = {_: 0 for _ in ('loglines', 'commits', 'touches', 'skip', 'errors'
                            )}

    logging.basicConfig(level=args.loglevel, format='%(message)s')
    # noinspection PyUnresolvedReferences
    log.trace("Arguments: %s", args)

    # Using both os.chdir() and `git -C` is redundant, but might prevent side
    # effects `git -C` alone could be enough if we make sure that:
    # - touch() / os.utime() path argument is always prepended with git.workdir
    try:
        git = Git()
    except Git.Error as e:
        # Not in a git repository, and git already informed user on stderr.
        # So we just...
        return e.returncode

    args.meta_file = os.path.join(git.workdir, args.meta_file)
    if os.path.exists(args.meta_file):
        filelist = parse_meta(args.meta_file)
    else:
        log.debug("Meta file %s does not exist.", args.meta_file)
        return

    # check last change of reference file commit time for newer commits
    reference_file_last_change = get_reference_latest_commit_time(
        git, filelist, args.reference_file)

    stats['totalfiles'] = stats['files'] = len(filelist)
    log.info(
        "{0:,} files to be processed in work dir".format(stats['totalfiles']))

    if not filelist:
        # Nothing to do. Exit silently and without errors, just like git does
        return

    # Process the log until all files are 'touched'
    check_files(git, filelist, reference_file_last_change, stats)

    assert len(filelist) == 0

    # Final statistics
    def log_info(msg, *a, width=13):
        ifmt = '{:%d,}' % (width,)  # not using 'n' for consistency with ffmt
        ffmt = '{:%d,.2f}' % (width,)
        # %-formatting lacks a thousand separator, must pre-render with .format()
        log.info(msg.replace('%d', ifmt).replace('%f', ffmt).format(*a))

    log_info(
        "Statistics:\n"
        "%f seconds\n"
        "%d log lines processed\n"
        "%d commits evaluated",
        time.time() - start, stats['loglines'], stats['commits'])

    if stats['touches'] != stats['totalfiles']:
        log_info("%d files", stats['totalfiles'])
    if stats['skip']:
        log_info("%d files skipped", stats['skip'])
    if stats['files']:
        log_info("%d files missing", stats['files'])
    if stats['errors']:
        log_info("%d file update errors", stats['errors'])

    log_info("%d files updated", stats['touches'])

    if args.test:
        log.info("TEST RUN - No files modified!")


# Keep only essential, global assignments here.
# Any other logic must be in main()
log = setup_logging()
args = parse_args()

# Make sure this is always set last to ensure --test behaves as intended
if args.test:
    touch = dummy

# UI done, it's showtime!
try:
    sys.exit(main())
except KeyboardInterrupt:
    log.info("\nAborting")
    signal.signal(signal.SIGINT, signal.SIG_DFL)
    os.kill(os.getpid(), signal.SIGINT)
