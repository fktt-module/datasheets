#!/usr/bin/env python3
# -*- coding: utf8 -*-
"""
Creates a json file with information known as yellow pages
from all datasheet files in given directory path.
The output file, named '{1}'
by default (depending on selected type), is also stored
into given directory path.

Examples:
   {0} path/to/directory
   {0} -o file_name path/to/directory
   {0} -t empfang path/to/directory

"""
# file resides in .github/scripts
import argparse
import json
import os
import pathlib
import sys
import textwrap
# noinspection PyPep8Naming
import xml.etree.ElementTree as ET
from collections import OrderedDict

DEFAULT_TYPE = "versand"
BASE_FILE_NAME = 'GelbeSeiten{}.json'
DEFAULT_FILE_NAME = BASE_FILE_NAME.format(DEFAULT_TYPE.title())

if __name__ == '__main__':
    script_name = os.path.basename(sys.argv[0])
    args_parser = argparse. ArgumentParser(
        description=textwrap.dedent(__doc__.format(
            script_name, BASE_FILE_NAME.format("[Versand|Empfang]"))),
        formatter_class=argparse.RawDescriptionHelpFormatter
    )
    args_parser.add_argument(
        'ds_files',
        metavar='path/to/directory',
        nargs=1,
        help='Directory where files are stored')
    args_parser.add_argument(
        '-o',
        '--out-file',
        metavar='file-name',
        nargs='?',
        required=False,
        default=DEFAULT_FILE_NAME,
        help='File where result is stored to (default: "{}")'.format(
            DEFAULT_FILE_NAME))
    args_parser.add_argument(
        '-t',
        '--book-type',
        choices=['versand', 'empfang'],
        nargs='?',
        required=False,
        default=DEFAULT_TYPE,
        help='Yellow pages book type (default: "{}")'.format(
            DEFAULT_TYPE))
    args = args_parser.parse_args()
    if args.out_file == DEFAULT_FILE_NAME and args.book_type == 'empfang':
        args.out_file = args.out_file.replace(DEFAULT_TYPE.title(),
                                              args.book_type.title())

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
    # outfile is stored in given directory; check if suffix json is present,
    # add if necessary
    out_file = pathlib.Path(_working_directory,
                            args.out_file).with_suffix('.json')

    _key = 'empfaenger' if args.book_type == 'empfang' else 'versender'
    all_in_one = []
    for ds_element in sorted(_working_directory.glob('*.xml')):
        root = ET.parse(ds_element).getroot()
        epoche = ds_element.stem.split('-')
        # gv -> verlader -> versand -> ladegut,...
        for verlader in root.findall('./gv/verlader'):
            for ladegut in verlader.findall(args.book_type + '/ladegut'):
                s_oder_e = ladegut.get('typ', '').lower()
                ladestellen_namen = []
                for ladestellen_id in ladegut.get('ladestelle').split(" "):
                    ladestellen_name = root.find(
                        "./gv/ladestelle[@id='" + ladestellen_id + "']/name")
                    if ladestellen_name is None:
                        print(ds_element, ladegut.find('name').text,
                              ladestellen_id)
                        ladestellen_namen.append(ladestellen_id)
                    else:
                        ladestellen_namen.append(ladestellen_name.text)
                verwaltung = root.find('./verwaltung')
                all_in_one.append(OrderedDict({
                    'epoche': epoche[1] if len(epoche) > 1 else 'IV',
                    'kuerzel': root.find('./kuerzel').text,
                    'verwaltung':
                        verwaltung.text if verwaltung is not None else '',
                    'kategorie': '',
                    'produkt': ladegut.find('name').text,
                    _key: verlader.find('name').text,
                    'wagengattung': ladegut.find('gattung').text,
                    'betriebsstelle': root.find('./name').text,
                    'ladestelle': ', '.join(ladestellen_namen),
                    'stueckgut': 'X' if s_oder_e == 'stueckgut' else '',
                    'eilgut': 'X' if s_oder_e == 'expressgut' else '',
                    'besonderheiten': ''
                }))

    if len(all_in_one) > 0:
        with open(out_file, 'w') as jsonfile:
            json.dump(all_in_one, jsonfile, separators=(',', ':'))
