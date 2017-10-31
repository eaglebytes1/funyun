# -*- coding: utf-8 -*-
import importlib
import os

package_name = os.path.basename(__file__).split('_')[0]
app = importlib.import_module(package_name).app
configure_logging = importlib.import_module(package_name +
                                            '.logs').configure_logging
init_filesystem = importlib.import_module(package_name +
                                          '.filesystem').init_filesystem
init_filesystem(app)
configure_logging(app)

if __name__ == '__main__':
    app.run()
