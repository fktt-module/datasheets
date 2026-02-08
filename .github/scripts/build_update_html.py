#!/usr/bin/env python3
# -*- coding: utf8 -*-
"""
Creates html files from all datasheet files by transforming
xml using xslt in given directory path.

Examples:
   {} path/to/directory

"""
# file resides in .github/scripts
import argparse
import os
import pathlib
import sys
import textwrap
from lxml import etree

if __name__ == '__main__':
    script_name = os.path.basename(sys.argv[0])
    args_parser = argparse. ArgumentParser(
        description=textwrap.dedent(__doc__.format(script_name)),
        formatter_class=argparse.RawDescriptionHelpFormatter
    )
    args_parser.add_argument(
        'ds_files',
        metavar='path/to/directory',
        nargs=1,
        help='Directory where files are stored')
    args = args_parser.parse_args()

    # provide given file as resolved absolute path
    ds_file = pathlib.Path(args.ds_files[0]).resolve()

    if not ds_file.exists():
        args_parser.error(
            'Given path "{}" does not exists.'.format(args.ds_files[0]))

    # given path must exist and a folder
    if not ds_file.is_dir():
        args_parser.error(
            'Given path "{}" is not a folder!'.format(args.ds_files[0]))

    _working_directory = ds_file.absolute()
    _styles = []
    style: pathlib.Path
    # find all stylesheets
    for style in pathlib.Path(_working_directory).glob('bahnhof*.xsl'):
        _suffix = style.stem.removeprefix('bahnhof')
        if _suffix == '_tpl':  # ignore template stylesheet
            continue
        _styles.append(
            {'suffix': _suffix,
             'transform': etree.XSLT(etree.XML(style.read_bytes()))})

    xml: pathlib.Path
    for xml in pathlib.Path(_working_directory).glob('*.xml'):
        doc = etree.fromstring(xml.read_bytes())
        for _style in _styles:
            html_name = xml.stem + _style['suffix'] + '.html'
            html_file = pathlib.Path(_working_directory, html_name)
            try:
                html_file.write_bytes(_style['transform'](doc))
            except etree.XSLTApplyError as e:
                print(xml, html_file)
                print(e)
