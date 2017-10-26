# This file sets values of the following variables that must be set
# before the server is started if those values are not defaults.
# The values are:
#
#    {{NAME.upper()}}_MODE       Global configuration value selector.
#    {{NAME.upper()}}_SETTINGS   Name of configuration file.
#    {{NAME.upper()}}_VAR        Home of the redis/ and run/ directories.
#    {{NAME.upper()}}_LOG        Home of the logfiles.
#    {{NAME.upper()}}_TMP        Home of the tmp files.
#
#  All other non-default values are set by the configuration file after the
#  server has started.
#
{% if MODE != 'default' %}
export {{NAME.upper()}}_MODE="{{MODE}}"
{% endif %}
{% if SETTINGS != NAME+('-debug' if DEBUG else '')+'.conf' %}
export {{NAME.upper()}}_SETTINGS="{{SETTINGS}}"
{% endif %}
{% if VAR != ROOT+'/var' %}
export {{NAME.upper()}}_VAR="{{VAR}}"
{% endif %}
{% if LOG != VAR+'/log' %}
export {{NAME.upper()}}_LOG="{{LOG}}"
{% endif %}
{% if TMP != VAR+'/tmp' %}
export {{NAME.upper()}}_TMP="{{TMP}}"
{% endif %}
