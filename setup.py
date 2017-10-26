# -*- coding: utf-8 -*-
#
# This file is part of funyun.
# Copyright (C) 2017, EagleBytes.
#
# funyun is free software; you can redistribute it and/or modify
# it under the terms of the 3-Clause BSD License; see LICENSE.txt
# file for more details.
#
"""funyun -- image recognition and geolocation tags in photos."""
#
# Developers, install with:
#    pip install -r requirements.txt
#    python setup.py develop
#
from distutils.cmd import Command
import distutils.log as logger
from os import environ as environ
import platform
import shutil
import string
import subprocess # noqa
import sys
from setuptools import setup, find_packages
from setuptools.command import build_py, develop, install
# Version restrictions and dependencies
if sys.version_info < (3, 4, 0, 'final', 0):
    raise SystemExit("This package requires python 3.4 or higher.")
elif sys.version_info >= (3, 6, 0, 'final', 0):
    from secrets import choice
else:
    from random import choice
from pathlib import Path  # python 3.4

NAME = 'funyun'
ENV_SCRIPT_INNAME = 'server_env.sh'
ENV_SCRIPT_OUTNAME = NAME + '_env'
RUN_SCRIPT_INNAME = 'server_run.py'
RUN_SCRIPT_OUTNAME = NAME + '_run.py'
BUILD_PATH = Path('.') / NAME / 'bin'
PASSWORD_LENGTH = 12
DIR_MODE = 0o775

class InstallBinariesCommand(Command):
    """Install binaries to virtual environment bin directory."""
    description = 'Copy binaries to install location'
    user_options = [('bindir=', None, 'binaries directory')]

    def initialize_options(self):
        """Set default values for options."""
        if NAME.upper() + '_ROOT' in environ:
            install_path = Path(environ[NAME.upper() + '_ROOT'])
        else:
            install_path = Path(sys.prefix)
        self.bin_path = install_path / 'bin'
        self.etc_path = install_path / 'etc'

    def finalize_options(self):
        """Post-process options."""
        if not self.bin_path.exists():
            logger.info(
                'creating binary directory "%s"' % (str(self.bin_path)))
            self.bin_path.mkdir(parents=True, mode=DIR_MODE)
        if not self.etc_path.exists():
            logger.info('creating etc directory "%s"' % (str(self.etc_path)))
            self.etc_path.mkdir(parents=True, mode=DIR_MODE)

    def create_config_file(self, file_name):
        """Initializes config file with secret key."""
        file_path = self.etc_path / file_name
        if not file_path.exists():
            with file_path.open(mode='w') as config_fh:
                print('Creating instance config file at "%s".' % str(
                    file_path))
                alphabet = string.ascii_letters + string.digits
                nchars = 0
                secret_key = ''
                while nchars < PASSWORD_LENGTH:
                    secret_key += choice(alphabet) # noqa
                    nchars += 1
                print('SECRET_KEY = "%s" # set at install time' % (secret_key),
                      file=config_fh) # noqa

    def run(self):
        """Run command."""
        # Check if build is disabled by environmental variable.
        no_binaries = NAME.upper() + '_NO_BINARIES'
        if no_binaries in environ and \
                environ[no_binaries] == 'True':
            logger.info('skipping install of binary files')
        else:
            logger.info(
                'copying environment script to %s' % (str(self.bin_path)))
            shutil.copy2(str(BUILD_PATH / ENV_SCRIPT_INNAME),
                         str(self.bin_path / ENV_SCRIPT_OUTNAME))
            shutil.copy2(str(BUILD_PATH / RUN_SCRIPT_INNAME),
                         str(self.bin_path / RUN_SCRIPT_OUTNAME))
            my_python = self.bin_path / (NAME + '_python')
            if not my_python.exists():
                logger.info('creating ' + str(my_python) + ' link')
                my_python.symlink_to(sys.executable)
            self.create_config_file(NAME + '.conf')



class DevelopCommand(develop.develop):
    """Build C binary as part of develop."""

    def run(self):
        self.run_command('install_binaries')
        develop.develop.run(self)


class InstallCommand(install.install):
    """Install C binary as part of install."""

    def run(self):
        self.run_command('install_binaries')
        install.install.run(self)


#
# Most of the setup function has been moved to setup.cfg,
# which requires a recent setuptools to work.  Current
# anaconda setuptools is too old, so it is strongly
# urged this package be installed in a virtual environment.
#
tests_require = [
    'check-manifest>=0.25',
    'coverage>=4.0',
    'isort>=4.2.2.2',
    'pydocstyle>=1.0.0',
    'pytest-cache>=1.0',
    'pytest-cov>=1.8.0',
    'pytest-pep8>=1.0.6',
    'pytest>=2.8.0'
]

extras_require = dict(docs=['Sphinx>=1.4.2'], tests=tests_require)

extras_require['all'] = []
for reqs in extras_require.values():
    extras_require['all'].extend(reqs)

packages = find_packages()

setup(
    description=__doc__,
    packages=packages,
    setup_requires=['packaging',
                    'setuptools>30.3.0',
                    'setuptools-scm>1.5'
                    ],
    entry_points={
        'console_scripts': [NAME + ' = ' + NAME + '.cli:cli']
    },
    cmdclass={
        'develop': DevelopCommand,
        'install_binaries': InstallBinariesCommand,
        'install': InstallCommand
    },
    use_scm_version={
        'version_scheme': 'guess-next-dev',
        'local_scheme': 'dirty-tag',
        'write_to': NAME + '/version.py'
    },
    extras_require=extras_require,
    tests_require=tests_require,
)
