# -*- coding: utf-8 -*-
"""Command-line interpreter functions.

These functions extend the Flask CLI.

"""
#
# Standard library imports.
#
import json
import os
import pkg_resources
import pkgutil
import sys
import types
from distutils.util import strtobool
from pydoc import locate
from pathlib import Path  # python 3.4 or later
#
#
# third-party imports.
import click
from flask import current_app
from flask.cli import FlaskGroup
from jinja2 import Environment, PackageLoader
import htpasswd
#
# Local imports.
#
from .logger import configure_logging
from .filesystem import init_filesystem
from .config_file import create_config_file, write_kv_to_config_file
from .config import print_config_var
#
# Global variables.
#
AUTHOR = 'Joel Berendzen'
EMAIL = 'joelb@generisbio.com'
COPYRIGHT = """Copyright (C) 2017, The EagleBytes Team.
All rights reserved.
"""
#
# CLI entry point.
#


@click.group(cls=FlaskGroup,
             epilog=AUTHOR + ' <' + EMAIL + '>. ' + COPYRIGHT)
def cli():
    pass


@cli.command()
def run(): # pragma: no cover
    """Run a server directly."""
    from .logging import configure_logging
    print('Direct start, use of gunicorn is recommended for production.', file=sys.stderr)
    port = current_app.config['PORT']
    host = current_app.config['HOST']
    debug = current_app.config['DEBUG']
    init_filesystem(current_app)
    configure_logging(current_app)
    current_app.run(host=host,
                    port=port,
                    debug=debug)


@cli.command()
@click.option('--vartype',
              help='Type of variable, if not previously defined.',
              default=None)
@click.option('--verbose/--no-verbose', help='Verbose provenance.')
@click.option('--delete/--no-delete',
              help='Deletes config file, arguments ignored.')
@click.argument('var', required=False)
@click.argument('value', required=False)
def config(var, value, vartype, verbose, delete):
    """Gets, sets, or deletes config variables."""
    config_file_path = Path(current_app.config['ROOT']) / 'etc' /\
        current_app.config['SETTINGS']
    if delete:
        if config_file_path.exists():
            print('Deleting config file %s.' % (str(config_file_path)))
            config_file_path.unlink()
            create_config_file(config_file_path)
            sys.exit(0)
        else:
            print('ERROR--config file %s does not exist.'
                  % (str(config_file_path)))
            sys.exit(1)
    if value is None:  # No value specified, this is a get.
        config_file_obj = types.ModuleType('config')  # noqa
        if config_file_path.exists():
            config_file_status = 'exists'
            config_file_obj.__file__ = str(config_file_path)
            try:
                with config_file_path.open(mode='rb') as config_file:
                    exec(compile(config_file.read(), str(config_file_path),
                                 'exec'),
                         config_file_obj.__dict__)
            except IOError as e:
                e.strerror = 'Unable to load configuration file (%s)' \
                             % e.strerror
                raise
        else:
            config_file_status = 'does not exist'
            config_file_obj.__file__ = None
        if var is None:  # No variable specified, list them all.
            print('The instance-specific config file at %s %s.' % (
                str(config_file_path),
                config_file_status))
            print('Listing all %d defined configuration variables:'
                  % (len(current_app.config)))
            for key in sorted(current_app.config):
                print_config_var(current_app, key, config_file_obj)
            return
        else:
            var = var.upper()
            if var.startswith(__name__.upper() + '_'):
                var = var[len(__name__) + 1:]
            if var in current_app.config:
                if verbose:
                    print_config_var(current_app, var, config_file_obj)
                else:
                    print(current_app.config[var])
                return
            else:
                print('"%s" not found in configuration variables.' % var,
                      file=sys.stderr)
                sys.exit(1)
    else:  # Must be setting.
        var = var.upper()
        if var.startswith(__name__.upper() + '_'):
            var = var[len(__name__) + 1:]
        old_value = None
        if var in current_app.config and vartype is None \
                and not current_app.config[
                    var] is None:  # type defaults to current type
            old_value = current_app.config[var]
            value_type = type(old_value)
        else:  # get type from command line, or str if not specified
            if vartype is None:
                vartype = 'str'
            value_type = locate(vartype)
        if value_type == bool:
            value = bool(strtobool(value))
        elif value_type == str:
            pass
        else:  # load through JSON to handle dict and list types
            try:
                jsonobj = json.loads(value)
            except json.decoder.JSONDecodeError:
                print(
                    'ERROR--Unparseable string "%s". Did you use quotes?'
                    % value, file=sys.stderr)
                sys.exit(1)
            try:
                value = value_type(jsonobj)
            except TypeError:
                print(
                    'ERROR--Unable to convert "%s" of type %s to type %s.'
                    % (value, type(jsonobj).__name__, value_type.__name__),
                    file=sys.stderr)
                sys.exit(1)
        #
        # Write key/value pair to config file.
        #
        create_config_file(config_file_path)
        write_kv_to_config_file(config_file_path,
                                var,
                                value,
                                value_type,
                                old_value)


@cli.command()
def test_logging():
    """Test logging at the different levels."""
    configure_logging(current_app)
    current_app.logger.debug('Debug message.')
    current_app.logger.info('Info message.')
    current_app.logger.warning('Warning message.')
    current_app.logger.error('Error message.')


def walk_package(root):
    """Walk through a package_resource.

    :type module_name: basestring
    :param module_name: module to search in
    :type dirname: basestring
    :param dirname: base directory
    """
    dirs = []
    files = []
    for name in pkg_resources.resource_listdir(__name__, root):
        fullname = root + '/' + name
        if pkg_resources.resource_isdir(__name__, fullname):
            dirs.append(fullname)
        else:
            files.append(name)
    for new_path in dirs:
        yield from walk_package(new_path)
    yield root, dirs, files


def copy_files(pkg_subdir, out_head, force, notemplate_exts=None):
    """Copy files from package, with templating.

    :param pkg_subdir:
    :param out_head:
    :param force:
    :param notemplate_exts:
    :return:
    """
    for root, dirs, files in walk_package(pkg_subdir):
        del dirs
        split_dir = os.path.split(root)
        if split_dir[0] == '':
            out_subdir = ''
        else:
            out_subdir = '/'.join(list(split_dir)[1:])
        out_path = out_head / out_subdir
        if not out_path.exists() and len(files) > 0:
            print('Creating "%s" directory' % str(out_path))
            out_path.mkdir(mode=int(current_app.config['DIR_MODE'], 8),
                           parents=True)
        #
        # Initialize Jinja2 template engine on this directory.
        #
        template_env = Environment(loader=PackageLoader(__name__, root),
                                   trim_blocks=True,
                                   lstrip_blocks=True
                                   )
        for filename in files:
            try:
                ext = os.path.splitext(filename)[1].lstrip('.')
            except IndexError:
                ext = ''
            if notemplate_exts is not None and ext in notemplate_exts:
                templated = 'directly'
                data_string = pkgutil.get_data(__name__,
                                               root + '/' +
                                               filename).decode('UTF-8')
            else:
                templated = 'from template'
                template = template_env.get_template(filename)
                data_string = template.render(current_app.config)
            outfilename = filename.replace(
                'server', current_app.config['NAME'])
            file_path = out_path / outfilename
            if file_path.exists() and not force:
                print('ERROR -- File %s already exists.' % str(file_path) +
                      '  Use --force to overwrite.')
                sys.exit(1)
            elif file_path.exists() and force:
                operation = 'Overwriting'
            else:
                operation = 'Creating'
            with file_path.open(mode='wt') as fh:
                print('%s file "%s" %s.'
                      % (operation, str(file_path), templated))
                fh.write(data_string)
            if filename.endswith(
                    '.sh') or filename == current_app.config['NAME']:
                file_path.chmod(0o755)


@cli.command()
@click.option('--force/--no-force', help='Force overwrites of existing files',
              default=False)
@click.option('--init/--no-init', help='Initialize filesystem',
              default=True)
@click.option('--var/--no-var', help='Create files in var directory',
              default=True)
def create_instance(force, init, var):
    """Configures instance files."""
    copy_files('etc', Path(current_app.config['ROOT']) / 'etc', force)
    if var:
        copy_files('var', Path(current_app.config['VAR']), force)
    if init:
        init_filesystem(current_app)


@cli.command()
@click.option('--force/--no-force',
              help='Force overwrites of existing files',
              default=False)
def set_htpasswd(force):
    """Sets the site password to SECRET_KEY."""
    htpasswd_file = current_app.config['ROOT'] + '/etc/nginx/htpasswd'
    htpasswd_path = Path(htpasswd_file)
    user = current_app.config['NAME']
    secret_key = current_app.config['SECRET_KEY']
    print('Setting password for user %s to %s. ' % (user, secret_key))
    if not htpasswd_path.exists():
        print('Creating htpasswd file.')
        htpasswd_path.touch()
    with htpasswd.Basic(htpasswd_file) as userdb:
        if len(secret_key) == 0:
            print('ERROR--must set SECRET_KEY first.')
            sys.exit(1)
        try:
            userdb.add(user, secret_key)
        except htpasswd.basic.UserExists:
            if force:
                print('Updating site password for existing user %s.' % user)
                userdb.change_password(user, secret_key)
            else:
                print('ERROR--user %s already exists in htpasswd, use --force.')
                sys.exit(1)


@cli.command()
@click.option('--force/--no-force', help='Force overwrites of existing files',
              default=False)
@click.option('--configonly/--no-configonly', help='Only create config file',
              default=False)
def create_test_files(force, configonly):
    """Create test files."""
    if not configonly:
        copy_files('test',
                   Path('.'),
                   force,
                   notemplate_exts=['hmm', 'faa', 'sh'])
    copy_files('user_conf',
               Path(os.path.expanduser(current_app.config['USER_CONFIG_PATH'])),
               force)
