# Security Policy

## Reporting a vulnerability

Please **do not** open a public issue for security vulnerabilities.

Report privately via GitHub's built-in
[**Report a vulnerability**](https://github.com/maptic/mounty/security/advisories/new) form.

We aim to acknowledge reports within 5 business days and to provide a remediation timeline after
triage.

## Scope notes

- Mounty stores its volume list and preferences in `UserDefaults`. It does **not** store share
  credentials — authentication is delegated to the macOS Keychain / NetFS.
- Mounty performs TCP reachability checks (SMB port 445) and mounts network shares via the system
  `NetFS` framework. It executes no remote code.

## Supported versions

Only the latest released version receives security fixes.
