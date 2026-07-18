#!/usr/bin/env python3
"""v0.6.17 regression test: the plugin must load and run LAN-only WITHOUT
PyJWT/cryptography installed (embedded hosts - see docs/third-party-printers.md
- have no pip and no prebuilt wheels for them).

Stdlib-only on purpose so it runs anywhere Python 3.9+ does:

    python3 klipper-plugin/tests/test_lan_only_no_deps.py

Covers:
  1. import with jwt + cryptography BLOCKED  -> module loads, error recorded
  2. MoongatePlugin construction in lan_only -> no cloud objects, no keygen
  3. import with real deps (when installed)  -> no error recorded (else skip)
"""

import importlib.util
import sys
import tempfile
from pathlib import Path

PLUGIN_PATH = Path(__file__).resolve().parents[1] / "moongate_standalone.py"
BLOCKED     = ("jwt", "cryptography")


def _load(name):
    spec = importlib.util.spec_from_file_location(name, PLUGIN_PATH)
    mod  = importlib.util.module_from_spec(spec)
    # Register before exec: @dataclass looks its module up in sys.modules.
    sys.modules[name] = mod
    try:
        spec.loader.exec_module(mod)
    except BaseException:
        del sys.modules[name]
        raise
    return mod


class FakeServer:
    def register_endpoint(self, *a, **k):      pass
    def register_remote_method(self, *a, **k): pass
    def lookup_component(self, *a, **k):       raise KeyError("not in test")
    def get_host_info(self):                   return {"port": 80}
    def error(self, msg, code=500):            return RuntimeError(f"{code}: {msg}")


class FakeConfig:
    """Duck-typed stand-in for Moonraker's ConfigHelper ([moongate] section)."""
    def __init__(self, opts):
        self._opts   = opts
        self._server = FakeServer()

    def get_server(self):            return self._server
    def get(self, k, d=None):        return self._opts.get(k, d)
    def getboolean(self, k, d=None): return self._opts.get(k, d)
    def getint(self, k, d=None):     return self._opts.get(k, d)


def test_import_without_deps():
    # None in sys.modules makes `import <name>` raise ImportError.
    for name in BLOCKED:
        assert name not in sys.modules or sys.modules[name] is None, (
            f"{name} already imported - run this test in its own process")
        sys.modules[name] = None
    try:
        mod = _load("moongate_nodeps")
    finally:
        for name in BLOCKED:
            del sys.modules[name]
    assert mod._CLOUD_DEPS_ERROR is not None, "deps error not recorded"
    assert "PyJWT" in mod._CLOUD_DEPS_ERROR
    # Class definitions must survive the missing imports (only calls need them)
    for cls in ("MoongatePlugin", "DeviceKey", "JwksCache",
                "AccessTokenVerifier", "HeartbeatLoop", "PrintEventWatcher"):
        assert hasattr(mod, cls), f"{cls} missing from module"
    return mod


def test_lan_only_construction(mod):
    with tempfile.TemporaryDirectory() as tmp:
        plugin = mod.MoongatePlugin(FakeConfig({
            "lan_only":  True,
            "data_path": tmp,
        }))
        assert plugin.lan_only is True
        assert plugin._plugin_error is None, "lan_only must not report an error"
        for attr in ("device", "jwks", "verifier", "sb", "heartbeat", "watcher"):
            assert getattr(plugin, attr) is None, f"{attr} built in lan_only"
        assert plugin._moonraker_port == 80, "get_host_info port not used"
        assert not (Path(tmp) / "device_ed25519").exists(), \
            "lan_only must not generate a device key"
        # moonraker.conf's lan_only wins over config.json's default (False)
        assert plugin._lan_only_override is True


def test_import_with_deps():
    try:
        import jwt          # noqa: F401
        import cryptography # noqa: F401
    except ImportError:
        print("  (real deps not installed here - normal-import check skipped)")
        return
    mod = _load("moongate_withdeps")
    assert mod._CLOUD_DEPS_ERROR is None, mod._CLOUD_DEPS_ERROR


if __name__ == "__main__":
    mod = test_import_without_deps()
    print("PASS import with jwt/cryptography blocked")
    test_lan_only_construction(mod)
    print("PASS lan_only construction without deps (no cloud objects, no keygen)")
    test_import_with_deps()
    print("PASS normal import")
    print("All good.")
