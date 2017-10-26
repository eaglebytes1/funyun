# -*- coding: utf-8 -*-
"""Set configuration file from setup.py or server"""
import string
import sys
from datetime import datetime
if sys.version_info >= (3, 6, 0, 'final', 0): # pragma: no cover
    from secrets import choice
else:
    from random import choice

DEFAULT_PASSWORD_LENGTH = 12
DEFAULT_GROUPING = 4
CONFIG_EXT = '.conf'
CONFIG_FILE_HEADER = """# -*- coding: utf-8 -*-
'''Overrides of default configurations.

This file is sourced after default configs but before environmental variables.

You may hand-edit this file, but it may be deleted with the config --delete
command.  Moreover, further sets will append and possibly supercede hand-edited
values.  

Note that configuration variables are all-caps.

Types are derived from python typing rules.
'''"""  # noqa


def generate_random_password(length=DEFAULT_PASSWORD_LENGTH,
                             grouping=DEFAULT_GROUPING):
    """Generate a password from an alphabet"""
    alphabet = string.ascii_lowercase + string.digits
    nchars = 0
    secret_key = ''
    while nchars < length:
        secret_key += choice(alphabet) # noqa
        nchars += 1
        if grouping and nchars < length and not nchars % grouping:
            secret_key += '-'
    return secret_key


def write_kv_to_config_file(file_path, key, value, valtype, previous_value):
    if valtype is str:
        quote = '"'
    else:
        quote = ''
    print('%s was %s%s%s, now set to %s%s%s (type %s) \n in config file "%s".'
          % (key,
             quote, previous_value, quote,
             quote, value, quote,
             type(value).__name__,
             str(file_path)))
    with file_path.open(mode='a') as config_fh:
        isodate = datetime.now().isoformat()[:-7]
        print('%s = %s%s%s # set at %s' % (key,
                                           quote,
                                           value,
                                           quote,
                                           isodate),
              file=config_fh)  # noqa


def create_config_file(file_path):
    """Initializes config file with secret key."""
    dir_path = file_path.parent
    if not dir_path.is_dir(): # pragma: no cover
        print('Creating application etc/ directory "%s".' % str(dir_path))
        dir_path.mkdir(mode=0o775,
                       parents=True)
    if not file_path.exists():
        with file_path.open(mode='w') as config_fh:
            print('Creating instance config file at "%s".' % str(
                file_path))
            print(CONFIG_FILE_HEADER, file=config_fh)
        #
        # Set SECRET_KEY to a random string.
        #
        write_kv_to_config_file(file_path,
                                'SECRET_KEY',
                                generate_random_password(),
                                str,
                                '')


if __name__ == '__main__':  # for development and testing purposes only
    from pathlib import Path  # python > 3.4
    create_config_file(Path(sys.prefix)/'settings.conf')
