# Changelog for `escalate`
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.3.0] - 2021-03-05
### Added
- Added `rescue_and_escalate`.

## [0.2.0] - 2021-03-02
### Added
- Added support for `on_escalate(log_first: false)`. The `escalate` gem will log first before
  escalating if either of these is true: there are no `on_escalate` blocks registered, or
  there are some and at least one of them passed `log_first: false`.

## [0.1.0] - 2021-02-03
### Added
- Added `Escalate.mixin` interface for mixing in `Escalate` with your module for easy escalation of rescued exceptions
- Added `escalate` method for escalating rescued exceptions with default behavior of logging to `STDERR`
- Added `Escalate.on_escalate` for registering escalation callbacks like `Honeybadger` or `Sentry`

[0.3.0]: https://github.com/Invoca/escalate/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/Invoca/escalate/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/Invoca/escalate/releases/tag/v0.1.0
