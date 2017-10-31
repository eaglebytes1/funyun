# -*- coding: utf-8 -*-
"""Define and handle configuration variables.

Definitions in this file are selected by the MYAPP_CONFIGURATION environmental
variable.  This variable may take on the following values:

* default: starts everything in production environment
* development: starts in debug environment (not secure)
* serverOnly: same as default, but without queues
* treebuilder: starts treebuilder queue only
* aligner: start aligner queue only


These definitions may be overridden via two ways:

1. A python file pointed to by the environmental variable MYAPP_SETTINGS.
2. An environmental variable that starts with MYAPP_.  If its value is
   "True" or "False", then it will be interpreted as a logical value.
   If its value can be parsed as an integer, then it will be.
"""
#
# Library imports.
#
import os
import platform
import sys
from getpass import getuser
from socket import getfqdn
from pathlib import Path  # python 3.4
#
# Third-party imports.
#
import arrow
#
# Local imports
#
from .version import version as __version__  # noqa
#
# Name of this service.
#
SERVICE_NAME = os.getenv('FLASK_APP', __name__.split('.')[0])
SERVICE_ORG = 'EagleBytes2017'
#
# Definitions that *must* be set in environmental variables.  Trying to
# set these from the config file would be too late, so they are
# not settable by that mechanism.
#
IMMUTABLES = ('ROOT', 'VAR', 'LOG', 'TMP')
PATHVARS = ('ROOT', 'VAR', 'LOG', 'TMP', 'DATA', 'USERDATA')


def get_path(name, default):
    """Get path from environ, checking absoluteness."""
    varname = SERVICE_NAME.upper() + '_' + name.upper()
    if varname in os.environ:
        path_str = os.environ[varname]
        try:
            Path(path_str).relative_to('/')
        except ValueError:  # relative path, not acceptable
            print('ERROR--path variable %s="%s" not absolute, ignoring'
                  % (varname, path_str))
            path_str = default
    else:
        path_str = default
    return path_str


class BaseConfig(object):
    """Base class for configuration objects.

    Note that only values in uppercase will be stored in the app
    configuration object.
    """
    #
    # Name of this service.
    #
    NAME = SERVICE_NAME
    ENVIRONMENT_DUMP = False
    #
    # Web site associated with this project.
    #
    PROJECT_HOME = 'https://github.com/' + SERVICE_ORG + '/' +SERVICE_NAME
    #
    # File path locations.  All of these are immutable except DATA.
    # Since different components run from different locations, these
    # must be absolute.  The immutable ones should be created before
    # runtime.
    #
    ROOT = get_path('ROOT', sys.prefix)
    VAR = get_path('VAR', ROOT + '/var')
    LOG = get_path('LOG', VAR + '/log')
    TMP = get_path('TMP', VAR + '/tmp')
    DATA = get_path('DATA', VAR + '/data/')
    USER_CONFIG_PATH = '~/.' + SERVICE_NAME
    #
    # Directory/file permissions.
    #
    PROCESS_UMASK = '0002'
    DIR_MODE = '755'  # Note interaction with process umask
    #
    # The DEBUG parameter has multiple implications:
    #           * access to python debugging via flask
    #           * logging levels set to DEBUG
    #           * configuration variables are printed
    #
    DEBUG = False
    PORT = 8000
    HOST = 'localhost'
    #
    # Create a logfile.
    #
    LOGFILE = True
    LOGFILE_NAME = None
    LOGFILE_MAXBYTES = 10000000
    LOGFILE_BACKUPCOUNT = 1
    #
    # Log only errors.
    #
    QUIET = False
    #
    # Test mode, includes propagation of errors.
    #
    TESTING = False
    #
    # User for rc scripts.
    #
    RC_USER = getuser()
    RC_GROUP = ''
    RC_VERBOSE = False
    #
    # Settings file name.
    #
    SETTINGS = SERVICE_NAME + '.conf'
    #
    # Current run.
    #
    HOSTNAME = getfqdn()
    DATETIME = arrow.now().format('YYYY-MM-DD HH:mm:ss')
    #
    # supervisord defs.
    #
    SUPERVISORD_UNIX_SOCKET = True
    SUPERVISORD_PORT = 58928
    SUPERVISORD_HOST = 'localhost'
    SUPERVISORD_USER = SERVICE_NAME
    SUPERVISORD_START_SERVER = True
    SUPERVISORD_START_CRASHMAIL = True
    SUPERVISORD_START_NGINX = True
    #
    # nginx defs.
    #
    NGINX_SERVER_NAME = 'localhost'
    system = platform.system()
    if system == 'Linux':
        import distro
        NGINX_LISTEN_ARGS = 'deferred'
        NGINX_EVENTS = 'use epoll;'
        DISTRIBUTION = distro.linux_distribution()[0].split()[0]
    elif system.endswith('BSD'): # pragma: no cover
        NGINX_LISTEN_ARGS = 'accept_filter=httpready'
        NGINX_EVENTS = 'use kqueue;'
        DISTRIBUTION = None
    elif system == 'Darwin': # pragma: no cover
        NGINX_LISTEN_ARGS = ''
        NGINX_EVENTS = 'use kqueue;'
        DISTRIBUTION = None
    else: # pragma: no cover
        NGINX_LISTEN_ARGS = ''
        NGINX_EVENTS = ''
        DISTRIBUTION = None
    NGINX_UNIX_SOCKET = False
    #
    # gunicorn defs--these will not be used in debugging mode.
    #
    GUNICORN_LOG_LEVEL = 'debug'
    GUNICORN_UNIX_SOCKET = True
    #
    # URL defs--these will be used in testing.
    #
    CURL_ARGS = ''
    CURL_URL = HOST + ':' + str(PORT)
    URL = ''
    #
    # crashmail defs.
    #
    CRASHMAIL_EMAIL = getuser()
    CRASHMAIL_EVENTS = 'PROCESS_STATE_EXITED'
    #
    # Controls of which processes get started by supervisord.
    # Setting these to empty strings will cause the process to
    # not be started.
    #
    # Monitoring at sentry.io.
    #
    SENTRY_DSN = ''
    #
    # Logging formatter.  Fields that are defined are:
    #    asctime: Time with too much precision
    #    levelname: Severity level.
    #    module:  module name.
    #    lineno: line number.
    #    pathname: File path.
    #    message: The message.
    #    url: Target address (if from a target).
    #    utcnow: Time in UTC.
    #    method: HTTP method.
    #    ip: Real IP address of the requester.
    #
    STDERR_LOG_FORMAT = '%(levelname)s: %(message)s'
    FILE_LOG_FORMAT = '%(levelname)s: %(message)s'
    #
    # Dropzone defs.
    #
    DROPZONE_ALLOWED_FILE_TYPE = 'image'
    DROPZONE_MAX_FILE_SIZE = 5
    DROPZONE_INPUT_NAME = 'image'
    DROPZONE_MAX_FILES = 1
    DROPZONE_DEFAULT_MESSAGE = 'Drop images here or click here to upload'
    DROPZONE_REDIRECT_VIEW = 'analyze'


class DevelopmentConfig(BaseConfig):
    """Start internal server, no queues."""
    DEBUG = True
    TESTING = True
    ENVIRONMENT_DUMP = True
    # Use debug config settings
    SETTINGS = SERVICE_NAME + '-debug.conf'


#
# Dictionary of configuration levels to be used with
# the _CONFIGURATION environmental variable.
#
config_dict = {
    'default': SERVICE_NAME + '.config.BaseConfig',
    'development': SERVICE_NAME + '.config.DevelopmentConfig'
}


def configure_app(app):
    """Configure the app, getting variables and setting up logging.

    :param app:
    :return:
    """
    config_name = os.getenv(SERVICE_NAME.upper() + '_MODE', 'default')
    if config_name not in config_dict:
        print('ERROR -- mode "%s" not known.' % config_name, file=sys.stderr)
        sys.exit(1)
    app.config.from_object(config_dict[config_name])
    app.config['MODE'] = config_name
    #
    # Do overrides from configuration, if it exists.
    #
    app.instance_path = os.getenv(SERVICE_NAME.upper() + '_ROOT',
                                  app.config['ROOT'])
    pyfile_name = os.getenv(SERVICE_NAME.upper() + '_SETTINGS',
                            app.config['SETTINGS'])
    pyfile_path = Path(app.instance_path) / 'etc' / pyfile_name
    pyfile_dict = {}
    try:
        with pyfile_path.open(mode='rb') as config_file:
            exec(compile(config_file.read(), str(pyfile_path),
                         'exec'),
                 pyfile_dict) # noqa
    except IOError:
        print('Unable to load configuration file "%s".' % str(pyfile_path))
    for internal_key in ['__doc__', '__builtins__']:
        if internal_key in pyfile_dict:
            del pyfile_dict[internal_key]
    if 'VAR' in pyfile_dict:  # VAR is hierarchical special case
        for subdir in ['tmp', 'log', 'data', 'userdata']:
            if not subdir.upper() in pyfile_dict:
                pyfile_dict[subdir.upper()] = pyfile_dict['VAR'] + '/' + subdir

    for key in pyfile_dict:
        app.config[key] = pyfile_dict[key]
    #
    # Do overrides from environmental variables.
    #
    for my_envvar, envvar in [(i, i[6:])
                              for i in sorted(os.environ)
                              if i.startswith(SERVICE_NAME.upper() + '_')]:
        value = os.environ[my_envvar]
        if value == 'True':
            value = True
        elif value == 'False':
            value = False
        else:
            try:
                value = int(value)
            except ValueError:
                pass
        if envvar not in PATHVARS:  # paths already configured from envvars
            app.config[envvar] = value
    #
    # Set version and platform (output only, not configurable).
    #
    app.config['VERSION'] = __version__
    app.config['PLATFORM'] = platform.system()
    #
    # Set maximum upload size at 16 MB.
    #
    #app.config['MAX_CONTENT_LENGTH'] = 16 * 1024 * 1024
    #
    # Supervisord socket type.
    #
    if app.config['SUPERVISORD_UNIX_SOCKET']:
        app.config['SUPERVISORD_SERVERURL'] = 'unix://%(ENV_' +\
                                              SERVICE_NAME.upper() +\
                                              '_VAR)s/run/supervisord.sock'
    else:
        app.config['SUPERVISORD_SERVERURL'] = 'http://' + \
            app.config['SUPERVISORD_HOST'] + ':' + \
            str(app.config['SUPERVISORD_PORT'])
    #
    # Gunicorn socket type.
    #
    if not app.config['SUPERVISORD_START_NGINX']:
        app.config['NGINX_URL'] = 'noURL'
        if app.config['GUNICORN_UNIX_SOCKET']:
            app.config['URL'] = 'unix://' +\
                                app.config['VAR'] +\
                                '/run/gunicorn.sock'
            app.config['GUNICORN_URL'] = 'unix://%(ENV_' +\
                SERVICE_NAME.upper() +\
                '_VAR)s/run/gunicorn.sock'
            app.config['CURL_ARGS'] = '--unix-socket ' + \
                                      app.config['VAR'] +\
                '/run/gunicorn.sock'
            app.config['CURL_URL'] = 'http://localhost'
        else:
            app.config['URL'] = 'http://' + \
                                app.config['HOST'] + ':' + \
                                str(app.config['PORT'])
            app.config['GUNICORN_URL'] = app.config['HOST'] + ':' + \
                str(app.config['PORT'])
            app.config['CURL_URL'] = app.config['HOST'] + ':' +\
                str(app.config['PORT'])
    else:  # serve gunicorn to nginx through a socket
        app.config['GUNICORN_UNIX_SOCKET'] = True
        app.config['GUNICORN_URL'] = 'unix://%(ENV_' + \
                                     SERVICE_NAME.upper() + \
                                     '_VAR)s/run/gunicorn.sock'
        if app.config['NGINX_UNIX_SOCKET']:
            app.config['URL'] = 'unix://' + \
                                app.config['VAR'] + \
                                '/run/nginx.sock'
            app.config['NGINX_URL'] = 'unix://' + \
                app.config['VAR'] + \
                '/run/nginx.sock'
            app.config['CURL_ARGS'] = '--unix-socket ' + \
                                      app.config['VAR'] + \
                                      '/run/nginx.sock'
            app.config['CURL_URL'] = 'http://' +\
                app.config['NGINX_SERVER_NAME']
        else:
            app.config['URL'] = 'http://' + \
                                app.config['HOST'] + ':' + \
                                str(app.config['PORT'])
            app.config['NGINX_URL'] = app.config['HOST'] + ':' + \
                str(app.config['PORT'])
            app.config['CURL_URL'] = app.config['HOST'] + ':' + \
                str(app.config['PORT'])


def print_config_var(app, var, config_file_obj):
    """Print configuration variable with type and provenance.

    :param var:
    :param obj:
    :return:
    """
    if __name__.upper() + '_' + var in os.environ:
        source = ' # <- from environment'
    elif var in config_file_obj.__dict__:
        source = ' # <- from config file'
    else:
        source = ''
    val = app.config[var]
    if isinstance(val, str):
        quote = '"'
    else:
        quote = ''
    print('  %s type(%s) =  %s%s%s %s' % (var,
                                          type(val).__name__,
                                          quote,
                                          val,
                                          quote,
                                          source))
