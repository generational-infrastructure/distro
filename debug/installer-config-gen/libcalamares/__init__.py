"""Minimal stub of the `libcalamares` Python module Calamares injects.

Provides just enough surface for `main.py`'s pure builder functions
(`render_configuration`, `render_flake`) to import and run. The
side-effecting host-env helpers are stubbed as no-ops; tests that
exercise them would need to wire their own fakes.
"""


class _GlobalStorage:
    def __init__(self, data=None):
        self._data = dict(data or {})

    def value(self, key):
        return self._data.get(key)

    def insert(self, key, value):
        self._data[key] = value

    # Test-only helper.
    def reset(self, data=None):
        self._data = dict(data or {})


class _Job:
    def setprogress(self, fraction):
        pass


class _Utils:
    @staticmethod
    def gettext_path():
        return "/dev/null"

    @staticmethod
    def gettext_languages():
        return []

    @staticmethod
    def debug(msg):
        pass

    @staticmethod
    def warning(msg):
        pass

    @staticmethod
    def error(msg):
        pass

    @staticmethod
    def host_env_process_output(cmd, callback=None, stdin=None):
        # Tests that need to observe filesystem writes should monkeypatch this.
        return 0


globalstorage = _GlobalStorage()
job = _Job()
utils = _Utils()
