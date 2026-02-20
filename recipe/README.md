# Eigen packaging on conda-forge

This feedstock supplies three related packages:

- **`eigen`** – the Eigen headers and CMake config files (header-only).
- **`eigen-abi`** – a tiny *marker* package used to pin the ABI **exposed by downstream libraries that use Eigen types in public headers**.
- **`eigen-abi-devel`** – an helper for downstream packages. It constrains the enabled CPU micro-architecture level and **exports a runtime dependency** on the matching `eigen-abi` via `run_exports`, so consumers of the downstream library automatically receive a compatible ABI marker.

---

## Why an ABI marker is needed

Eigen is header-only, but downstream C/C++ libraries often **use Eigen types in public headers** (e.g., `Eigen::Matrix<…>` in function signatures).  
Those libraries inherit ABI properties from Eigen. When Eigen changes ABI-relevant details, in particulary when the Eigen version changes, or the value of **`EIGEN_MAX_ALIGN_BYTES`** or when builds enable wider SIMD, binary compatibility of those downstream libraries changes.

To make these transitions safe for downstream users and packages, `eigen-abi` acts as a marker that is versioned so that **conda’s solver** can ensure that only libraries with a compatible Eigen abi are installed in the same environment.

---

## What `eigen-abi` encodes

The `eigen-abi` version encodes **two** things:

1. **Eigen version** used to compile headers into the downstream library.
2.  **`EIGEN_MAX_ALIGN_BYTES`**, i.e. an upper bound on the memory boundary in bytes on which dynamically and statically allocated data may be aligned by Eigen.

The value of `EIGEN_MAX_ALIGN_BYTES` is always `16` on non-`x86-64` architectures, while on `x86-64` on the specific SIMD options enabled, in particular:

| Condition | Tipical case in conda-forge | Default `EIGEN_MAX_ALIGN_BYTES` | 
|:---:|:---:|:---:|
| Neither `__AVX__` nor `__AVX512F__` macros defined. | Non-`x86-64` architecture, `x86-64` without `x86_64-microarch-level` installed, or `x86_64-microarch-level=1` or `x86_64-microarch-level=2` installed | `16` |
| `__AVX__` defined, while `__AVX512F__` not defined  | `x86-64` with `x86_64-microarch-level=3` installed, that adds the `-march=x86-64-v3` compilation option in `CXXFLAGS`, `CFLAGS` and `CPPFLAGS` env variables |  `32` |
| `__AVX512F__` |  `x86-64` with `x86_64-microarch-level=4` installed, that adds the `-march=x86-64-v4` compilation option in `CXXFLAGS`, `CFLAGS` and `CPPFLAGS` env variables | `64` | 

See for example for https://github.com/eigen-mirror/eigen/blob/5.0.0/Eigen/src/Core/util/ConfigureVectorization.h#L54-L73 and  the details on this preprocessor logic. Note that `EIGEN_MAX_ALIGN_BYTES` can have a default value different from the one described when compiling GPU-code, but this is not tracked here as the `eigen-abi` package only tracks the ABI of code targeting CPU.

To capture the default value of macros such as `EIGEN_MAX_ALIGN_BYTES` depending on the microarch level used, we introduce the eigen abi profile numbers, defined as in the following table:

| eigen_abi_profile |  Condition  | Default `EIGEN_MAX_ALIGN_BYTES` value  |
|:-----------------:|:------------------------:|:---------------------------------:|
| `100`             | Non-`x86-64` architecture or `x86-64` without `x86_64-microarch-level` installed, or `x86_64-microarch-level=1` or `x86_64-microarch-level=2` installed | `16` | 
| `80`             | `x86-64` with `x86_64-microarch-level=3` installed | `32` | 
| `70`             | `x86-64` with `x86_64-microarch-level=4` installed | `64` | 

In a nutshell the `eigen_abi_profile` captures the default value of `EIGEN_MAX_ALIGN_BYTES`, but it is kept generic to be able to generalize to different aspects of ABI in the future, and to explicitly control which `eigen_abi_profile` is installed by default if a users does not install explicitly any `x86_64-microarch-level` package.

The final versioning scheme of the `eigen-abi` package is the following: the first three numbers in the version correspond to the eigen version used, while the fourth version number corresponds to the `eigen_abi_profile`.
So for example `eigen-abi==3.4.0.100` is used to mark a compiled library that exposes Eigen in its public headers, and used Eigen `3.4.0`, with `eigen_abi_profile` `100`, i.e. `EIGEN_MAX_ALIGN_BYTES=16`.

> Note: in theory downstream projects can override Eigen’s alignment (e.g. by directly setting `EIGEN_MAX_ALIGN_BYTES` or setting other macros like `EIGEN_DONT_VECTORIZE`), but this interferes with conda-forge packaging. When packaging libraries that use Eigen in their public headers make sure that they do not override the default value of `EIGEN_MAX_ALIGN_BYTES` or other related macros.

---

## Role of `eigen-abi-devel`

Downstream packages that expose Eigen in public headers add `eigen-abi-devel` to **host** section, so that dependendency on the correct `eigen-abi` is achieved through `run_exports`, so any consumer of the downstream library automatically depends on the compatible ABI marker. This has two effects:

1. It ensure that the **version** of eigen is compatible with the one used in public ABI of used libraries.
2. It ensures a **consistent micro-architecture level** during the build (via the `x86_64-microarch-level` machinery), so the enabled SIMD width matches the marker that will be required at runtime.

Projects that do **not** expose Eigen in installed headers (either directly or transitively) do not need to deal with `eigen-abi` or `eigen-abi-devel` at all, and can just continue to depend on `eigen`.

## How downstream recipes use these packages

### If your library does not either **exposes** Eigen in public headers, or directly or indirectly includes headers of a library that **exposes** Eigen in public headers

Depend on `eigen` only, i.e.:

~~~yaml
# recipe.yaml (excerpt)
requirements:
  host:
    - eigen
~~~

### If your library either **exposes** Eigen in public headers, or directly or indirectly includes headers of a library that **exposes** Eigen in public headers

In this case, you need to add an `host` dependency on `eigen-abi-devel`: 

```yaml
# recipe.yaml (excerpt)
requirements:
  host:
    - eigen-abi-devel
```

This setup compiles your library consistently for the chosen level and **pins** consumers to the compatible `eigen-abi` automatically. As `eigen-abi-devel` has a run dependency on a compatible `eigen` version, the only dependency you need to have is on `eigen-abi-devel`.

Furthermore, to ensure that downstream consumers of your library install a compatible `eigen` and (on `x86-64`) `x86_64-microarch-level` you need to also ensure that they install `eigen-abi-devel`. For example, if your packages a `<pkg>-devel` output, you can add `eigen-abi-devel` as a `run` dependency to it.

Furthermore, in this case if in your feedstock you are using x86-64 [microarchitecture-optimized builds](https://conda-forge.org/docs/maintainer/knowledge_base/#microarch), you need to make sure that the `x86_64-microarch-level` package in `build` (used by the conda-forge machinery for microarchitecture-optimized builds) and the one in `host` (used by `eigen-abi-devel`) are actually compatible, this can be easily done by adding the `x86_64-microarch-level` output in both the `build` and `host`:

```yaml
# recipe.yaml (excerpt)
requirements:
  build:
    - if: unix and x86_64
      then: x86_64-microarch-level ==${{ microarch_level }}
  host:
    - if: unix and x86_64
      then: x86_64-microarch-level ==${{ microarch_level }}
    - eigen-abi-devel
```

---

## FAQs

### Why two different packages `eigen-abi` and `eigen-abi-devel` are needed?

The split between the two packages have been introduced to avoid that if a user installed a Python library that depended on a C++ library compiled with a non-standard `eigen_abi_profile`, the `x86_64-microarch-level` was silently installed, that would result in a non-intuitive behaviour.

### Why the introduction of `eigen_abi_profile` instead of directly encoding the value of `EIGEN_MAX_ALIGN_BYTES` in the `eigen-abi` version?

The main reason for decoupling the `eigen_abi_profile` and the `EIGEN_MAX_ALIGN_BYTES` value is to explicitly control which `eigen-abi-devel` version was installed by default.

## Discussion history 

For more details on why different `eigen-*` packages were introduced, see the following related issues:
* https://github.com/conda-forge/eigen-feedstock/pull/41
* https://github.com/conda-forge/conda-forge.github.io/issues/2092


