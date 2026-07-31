# Changelog

## [1.5.0](https://github.com/doublewordai/control-layer-chart/compare/v1.4.0...v1.5.0) (2026-07-31)


### Features

* support external keystore Redis services ([#92](https://github.com/doublewordai/control-layer-chart/issues/92)) ([f392e27](https://github.com/doublewordai/control-layer-chart/commit/f392e27cdd483a76a282579086928f3069cca3e8))

## [1.4.0](https://github.com/doublewordai/control-layer-chart/compare/v1.3.0...v1.4.0) (2026-07-21)


### Features

* support externally managed runtime secrets ([#88](https://github.com/doublewordai/control-layer-chart/issues/88)) ([db9bb9f](https://github.com/doublewordai/control-layer-chart/commit/db9bb9f6e94808c75e62862772e1f091550d5ab6))

## [1.3.0](https://github.com/doublewordai/control-layer-chart/compare/v1.2.0...v1.3.0) (2026-07-10)


### Features

* support split fusillade daemon deployments ([#86](https://github.com/doublewordai/control-layer-chart/issues/86)) ([b972f3d](https://github.com/doublewordai/control-layer-chart/commit/b972f3d76bf7dba9c3591efaf264c59d286492d8))

## [1.2.0](https://github.com/doublewordai/control-layer-chart/compare/v1.1.1...v1.2.0) (2026-07-07)


### Features

* add managed keystore storage class ([#84](https://github.com/doublewordai/control-layer-chart/issues/84)) ([c031144](https://github.com/doublewordai/control-layer-chart/commit/c031144267d15aa7150382f82cb03b0c617e7495))

## [1.1.1](https://github.com/doublewordai/control-layer-chart/compare/v1.1.0...v1.1.1) (2026-07-03)


### Bug Fixes

* wire ZDR keystore env into the fusillade daemon ([#82](https://github.com/doublewordai/control-layer-chart/issues/82)) ([d08f80a](https://github.com/doublewordai/control-layer-chart/commit/d08f80a4c7cd3753256c75d5b4e020d77f237c80))

## [1.1.0](https://github.com/doublewordai/control-layer-chart/compare/v1.0.0...v1.1.0) (2026-07-03)


### Features

* add ZDR keystore (Redis) and wrap-key wiring ([#79](https://github.com/doublewordai/control-layer-chart/issues/79)) ([4a66486](https://github.com/doublewordai/control-layer-chart/commit/4a66486ac189e08587d406207c4b1fcf521635e5))

## [1.0.0](https://github.com/doublewordai/control-layer-chart/compare/v0.11.0...v1.0.0) (2026-04-14)


### ⚠ BREAKING CHANGES

* the `scouter.*` values keys are no longer rendered. Consumers relying on the embedded scouter must deploy scouter separately (the chart lives at

### Features

* remove scouter sub-chart ([#70](https://github.com/doublewordai/control-layer-chart/issues/70)) ([ddb06d4](https://github.com/doublewordai/control-layer-chart/commit/ddb06d4f7c67ed46e91d571e8e41557239c9a625))


### Bug Fixes

* **chart:** roll pods when mounted Secret/ConfigMap changes ([#71](https://github.com/doublewordai/control-layer-chart/issues/71)) ([e49a923](https://github.com/doublewordai/control-layer-chart/commit/e49a92322b12a31ab0373a2a8aae56246995f5b4))

## [0.11.0](https://github.com/doublewordai/control-layer-chart/compare/v0.10.1...v0.11.0) (2026-02-18)


### Features

* allow emailTemplates configuration ([#64](https://github.com/doublewordai/control-layer-chart/issues/64)) ([2e87c71](https://github.com/doublewordai/control-layer-chart/commit/2e87c715a71c34de9530d59f0cba0c2361c19be2))

## [0.10.1](https://github.com/doublewordai/control-layer-chart/compare/v0.10.0...v0.10.1) (2026-02-13)


### Bug Fixes

* decode base64 bootstrap content in configmap ([#62](https://github.com/doublewordai/control-layer-chart/issues/62)) ([92026b0](https://github.com/doublewordai/control-layer-chart/commit/92026b0c4e04a763c9e3e9bb70fc8cf05827288f))

## [0.10.0](https://github.com/doublewordai/control-layer-chart/compare/v0.9.0...v0.10.0) (2026-02-13)


### Features

* simplify bootstrap defaults and add condition ([#60](https://github.com/doublewordai/control-layer-chart/issues/60)) ([10607be](https://github.com/doublewordai/control-layer-chart/commit/10607be664fa2fe3de823f213faa66d7c3aaebe6))

## [0.9.0](https://github.com/doublewordai/control-layer-chart/compare/v0.8.1...v0.9.0) (2026-02-09)


### Features

* add SYSTEM_API_KEY to secrets in values.yaml ([#53](https://github.com/doublewordai/control-layer-chart/issues/53)) ([9bf2a9d](https://github.com/doublewordai/control-layer-chart/commit/9bf2a9da0302594e38d26ce7258f2bab3d069c03))

## [0.8.1](https://github.com/doublewordai/control-layer-chart/compare/v0.8.0...v0.8.1) (2026-02-05)


### Features

* add scouter to control layer chart ([#51](https://github.com/doublewordai/control-layer-chart/issues/51)) ([a5d32c2](https://github.com/doublewordai/control-layer-chart/commit/a5d32c2570e4ee4e0b063699655cc9d573abe983))

## [0.8.0](https://github.com/doublewordai/control-layer-chart/compare/v0.7.0...v0.8.0) (2026-01-27)


### Features

* add startup probe support for control-layer and fusillade ([#46](https://github.com/doublewordai/control-layer-chart/issues/46)) ([3dcf67f](https://github.com/doublewordai/control-layer-chart/commit/3dcf67f3f48172fddd62069b840abf75ec071b1f))

## [0.7.0](https://github.com/doublewordai/control-layer-chart/compare/v0.6.1...v0.7.0) (2026-01-26)


### Features

* **fusillade:** add database pool configuration overrides ([#43](https://github.com/doublewordai/control-layer-chart/issues/43)) ([76182f7](https://github.com/doublewordai/control-layer-chart/commit/76182f72a9cf867ddf247d480884a23eecd11b19))

## [0.6.1](https://github.com/doublewordai/control-layer-chart/compare/v0.6.0...v0.6.1) (2026-01-08)


### Bug Fixes

* generation of postgres secret ([982a063](https://github.com/doublewordai/control-layer-chart/commit/982a063b05ad51e7debe51055741f7a09f3ea4aa))
* unit tests ([985181a](https://github.com/doublewordai/control-layer-chart/commit/985181a9b6460d49b109d1294cfbf2ec9ec2220c))

## [0.6.0](https://github.com/doublewordai/control-layer-chart/compare/v0.5.0...v0.6.0) (2026-01-07)


### Features

* add manual trigger to release-please workflow ([cb826c8](https://github.com/doublewordai/control-layer-chart/commit/cb826c84e56dff3bec0456c84f18af08ff9510f3))
* **fusillade:** add service and servicemonitor for metrics ([8ee1006](https://github.com/doublewordai/control-layer-chart/commit/8ee10062d846b397e123099389935dfe33e52265))


### Bug Fixes

* pin helm-unittest version in release-please workflow ([fec7531](https://github.com/doublewordai/control-layer-chart/commit/fec7531c73e58f456b8df3ba1e8ac0f08d507c47))

## [0.5.0](https://github.com/doublewordai/control-layer-chart/compare/v0.4.5...v0.5.0) (2025-12-30)


### Features

* isolate fusillade into its own deployment ([#36](https://github.com/doublewordai/control-layer-chart/issues/36)) ([79d1d1a](https://github.com/doublewordai/control-layer-chart/commit/79d1d1a650d441269ad0b32a09b1e280d9028037))

## [0.4.5](https://github.com/doublewordai/control-layer-chart/compare/v0.4.4...v0.4.5) (2025-12-12)


### Bug Fixes

* add bootstrap configuration more generally ([#34](https://github.com/doublewordai/control-layer-chart/issues/34)) ([97c7daf](https://github.com/doublewordai/control-layer-chart/commit/97c7dafbdd7ae520932472fec86b43351daf3ef0))

## [0.4.4](https://github.com/doublewordai/control-layer-chart/compare/v0.4.3...v0.4.4) (2025-12-04)


### Bug Fixes

* bootstrap js env var ([#32](https://github.com/doublewordai/control-layer-chart/issues/32)) ([00cdbd5](https://github.com/doublewordai/control-layer-chart/commit/00cdbd55be796f68e9051566976d1853ec9797e5))

## [0.4.3](https://github.com/doublewordai/control-layer-chart/compare/v0.4.2...v0.4.3) (2025-12-04)


### Bug Fixes

* mount bootstrap.js to static dir ([137da14](https://github.com/doublewordai/control-layer-chart/commit/137da1467946d24b860d3f60bd6376b68f1d2e38))

## [0.4.2](https://github.com/doublewordai/control-layer-chart/compare/v0.4.1...v0.4.2) (2025-12-04)


### Bug Fixes

* mount bootstrap to public ([#28](https://github.com/doublewordai/control-layer-chart/issues/28)) ([3df680f](https://github.com/doublewordai/control-layer-chart/commit/3df680f73a8491788b46894bb02811abb2a1f032))

## [0.4.1](https://github.com/doublewordai/control-layer-chart/compare/v0.4.0...v0.4.1) (2025-12-04)


### Bug Fixes

* posthog bootstrap ([#26](https://github.com/doublewordai/control-layer-chart/issues/26)) ([0255367](https://github.com/doublewordai/control-layer-chart/commit/0255367b6775ea634446d4c4455fe7fc855c5bf7))

## [0.4.0](https://github.com/doublewordai/control-layer-chart/compare/v0.3.0...v0.4.0) (2025-12-04)


### Features

* bootstrap script volume mount ([#24](https://github.com/doublewordai/control-layer-chart/issues/24)) ([406cc5e](https://github.com/doublewordai/control-layer-chart/commit/406cc5e5eb2f5ffcbb1eeeaecd5d8d8d43757697))

## [0.3.0](https://github.com/doublewordai/control-layer-chart/compare/v0.2.4...v0.3.0) (2025-11-28)


### Features

* bump 0.12.0 ([#22](https://github.com/doublewordai/control-layer-chart/issues/22)) ([f365dde](https://github.com/doublewordai/control-layer-chart/commit/f365dde330a2557ac3f3bd525ce412e451e4bcb8))

## [0.2.4](https://github.com/doublewordai/control-layer-chart/compare/v0.2.3...v0.2.4) (2025-11-27)


### Bug Fixes

* remove name/create options, consolidate database_url default setting ([#19](https://github.com/doublewordai/control-layer-chart/issues/19)) ([1519afc](https://github.com/doublewordai/control-layer-chart/commit/1519afcbed90aa911a27e472506fedc4364dd456))

## [0.2.3](https://github.com/doublewordai/control-layer-chart/compare/v0.2.2...v0.2.3) (2025-11-24)


### Bug Fixes

* bump control-layer to 0.8.1 ([#11](https://github.com/doublewordai/control-layer-chart/issues/11)) ([999ba96](https://github.com/doublewordai/control-layer-chart/commit/999ba96e1ff4b3d4d5ae44e6c4d7d8179aaf8288))

## [0.2.2](https://github.com/doublewordai/control-layer-chart/compare/v0.2.1...v0.2.2) (2025-11-24)


### Bug Fixes

* update appVersion to 0.8.0 ([#7](https://github.com/doublewordai/control-layer-chart/issues/7)) ([1734c49](https://github.com/doublewordai/control-layer-chart/commit/1734c496e15c95beb9b6d1fceda431945a924a09))

## [0.2.1](https://github.com/doublewordai/control-layer-chart/compare/v0.2.0...v0.2.1) (2025-11-20)


### Bug Fixes

* install helm unit test ([67f921f](https://github.com/doublewordai/control-layer-chart/commit/67f921f880511c90442e36df5a74c46a421f5da5))

## [0.2.0](https://github.com/doublewordai/control-layer-chart/compare/v0.1.2...v0.2.0) (2025-11-20)


### Features

* added in postgres deployment and unit tests ([#3](https://github.com/doublewordai/control-layer-chart/issues/3)) ([b4938b3](https://github.com/doublewordai/control-layer-chart/commit/b4938b33c51e6da8ea8db889fea25eda9c28032a))


### Bug Fixes

* use 0.7.0 as default app version ([8d6d8a9](https://github.com/doublewordai/control-layer-chart/commit/8d6d8a9998e1366078b1f16f464d43e7c706d46e))

## [0.1.2](https://github.com/doublewordai/control-layer-chart/compare/v0.1.1...v0.1.2) (2025-11-12)


### Bug Fixes

* issue with release trigger ([162fdf9](https://github.com/doublewordai/control-layer-chart/commit/162fdf9ef1fb109c1e006ef58003600c3587319e))

## [0.1.1](https://github.com/doublewordai/control-layer-chart/compare/v0.1.0...v0.1.1) (2025-11-12)


### Bug Fixes

* trigger release please ([63ac914](https://github.com/doublewordai/control-layer-chart/commit/63ac914556ff864d5dd0ec6eb775a6b69bc64ef1))

## 0.1.0 (TBD)

### Features

* Initial release of control-layer Helm chart
