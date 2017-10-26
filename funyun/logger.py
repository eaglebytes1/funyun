# -*- coding: utf-8 -*-
"""Set up logging.
"""
#
# Library imports.
#
import logging
import sys
from logging.handlers import RotatingFileHandler
from datetime import datetime
from pathlib import Path  # python 3.4
#
# Third-party imports.
#
from flask import request

#
# Global variables.
#
DEFAULT_FILE_LOGLEVEL = logging.INFO
DEFAULT_STDERR_LOGLEVEL = logging.WARNING


class ContextualFilter(logging.Filter):
    """A logging filter with request-based info."""

    def filter(self, record):
        record.utcnow = (datetime.utcnow().strftime('%Y-%m-%d %H:%M:%S%Z'))
        try:
            record.url = request.path
            record.method = request.method
        except RuntimeError:
            record.url = ''
            record.method = ''

        return True


def configure_logging(app):
    """ Configure logging to stderr and a log file.

    :param app:
    :return:
    """
    if app.config['DEBUG']: # pragma: no cover
        stderr_log_level = logging.DEBUG
    else:
        stderr_log_level = DEFAULT_STDERR_LOGLEVEL
    if app.config['QUIET']: # pragma: no cover
        file_log_level = logging.ERROR
    else:
        file_log_level = DEFAULT_FILE_LOGLEVEL
    app.logger.addFilter(ContextualFilter())
    app.logger.setLevel(logging.DEBUG)
    for handler in app.logger.handlers:  # set levels on existing handlers
        handler.setLevel(stderr_log_level)
        handler.setFormatter(
            logging.Formatter(app.config['STDERR_LOG_FORMAT']))
    #
    # Start Sentry monitoring, if SENTRY_DNS is configured.
    #
    if app.config['SENTRY_DSN'] is not '': # pragma: no cover
        from raven.contrib.flask import Sentry
        # import logging
        Sentry(app,
               dsn=app.config['SENTRY_DSN'],
               # logging=True,
               # level=logging.ERROR
                )

    #
    # Start log file.
    #
    if app.config['LOGFILE']:  # start a log file
        logfile_name = app.config['LOGGER_NAME'] + '_errors.log'
        app.config['LOGFILE_NAME'] = logfile_name
        logfile_path = Path(app.config['LOG']) / logfile_name
        if app.config['DEBUG']: # pragma: no cover
            print('Logging to file "%s".' % str(logfile_path),
                  file=sys.stderr)
        if not logfile_path.parent.is_dir():  # create logs/ dir
            try: # pragma: no cover
                logfile_path.parent.mkdir(mode=int(app.config['DIR_MODE'], 8),
                                          parents=True)
            except OSError: # pragma: no cover
                app.logger.error('Unable to create logfile directory "%s"',
                                 logfile_path.parent)
                raise OSError
        log_handler = RotatingFileHandler(str(logfile_path),
                                          maxBytes=app.config[
                                              'LOGFILE_MAXBYTES'],
                                          backupCount=app.config[
                                              'LOGFILE_BACKUPCOUNT'])

        log_handler.setLevel(file_log_level)
        werkzeug_logger = logging.getLogger('werkzeug')
        werkzeug_logger.addHandler(log_handler)
        for handler in app.logger.handlers:  # set levels on existing handlers
            handler.setLevel(file_log_level)
            handler.setFormatter(
                logging.Formatter(app.config['STDERR_LOG_FORMAT']))
        app.logger.addHandler(log_handler)
    #
    # Do some logging on startup.
    #
    app.logger.debug('Command line: "%s"', ' '.join(sys.argv))
    app.logger.debug('%s version %s',
                     app.config['LOGGER_NAME'],
                     app.config['VERSION'])
    app.logger.debug('Run started at %s',
                     datetime.now().strftime('%Y%m%d-%H%M%S'))
