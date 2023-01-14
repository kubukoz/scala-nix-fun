{
  inputs.nixpkgs.url = "github:nixos/nixpkgs";
  inputs.flake-utils.url = "github:numtide/flake-utils";
  inputs.smithy4s-nix.url = "github:kubukoz/smithy4s-nix";
  inputs.smithy4s-nix.inputs.nixpkgs.follows = "nixpkgs";
  inputs.smithy4s-nix.inputs.flake-utils.follows = "flake-utils";

  outputs = { self, nixpkgs, flake-utils, smithy4s-nix, ... }@inputs:
    flake-utils.lib.eachSystem [ "x86_64-linux" "x86_64-darwin" "aarch64-linux" "aarch64-darwin" ] (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [
            (import ./lib.nix)
          ];
        };

        sbt-typelevel-defaults = {
          "2.13" = [
            "-deprecation"
            "-encoding"
            "UTF-8"
            "-feature"
            "-unchecked"
            "-Ywarn-numeric-widen"
            "-Xlint:deprecation"
            "-Wunused:nowarn"
            "-Wdead-code"
            "-Wextra-implicit"
            "-Wnumeric-widen"
            "-Wunused:implicits"
            "-Wunused:explicits"
            "-Wunused:imports"
            "-Wunused:locals"
            "-Wunused:params"
            "-Wunused:patvars"
            "-Wunused:privates"
            "-Wvalue-discard"
            "-Ywarn-dead-code"
            "-Ybackend-parallelism"
            "10"
            "-language:_"
            "-J-Xmx1G"
          ];
        };
        catsVersion = "2.9.0";
        cats-src = pkgs.fetchFromGitHub {
          owner = "typelevel";
          repo = "cats";
          rev = "v${catsVersion}";
          sha256 = "sha256-L77puIa3+Dnzkg9vsOV7reaalyB+puOYUpzm7xA877k";
        };

        registry = {
          polyvariant.better-tostring =
            let version = "0.3.17"; in
            pkgs.scala-tools.mkScalacDerivation {
              pname = "better-tostring";
              inherit version;
              src = pkgs.fetchFromGitHub {
                owner = "polyvariant";
                repo = "better-tostring";
                rev = "v${version}";
                sha256 = "sha256-EFG/vdKrgoUMScQ1tg0ruXFqbT3D5XyZc7b9UT/spe8=";
              };
              sourceDirectories = [
                "plugin/src/main/scala"
                "plugin/src/main/scala-2"
              ];
              resourceDirectories = [ "plugin/src/main/resources" ];
              scalacOptions = sbt-typelevel-defaults."2.13";
            };

          polyvariant.colorize-scala =
            let version = "0.3.2"; in
            pkgs.scala-tools.mkScalacDerivation {
              pname = "colorize-scala";
              inherit version;
              src = pkgs.fetchFromGitHub {
                owner = "polyvariant";
                repo = "colorize-scala";
                rev = "v${version}";
                sha256 = "sha256-dJyjeq540NvdVFbptIelJSSSRk6tPc3sK6qO5dZL3LI";
              };
              sourceDirectories = [
                "core/shared/src/main/scala"
                "core/jvm-native/src/main/scala"
              ];
              scalacOptions = sbt-typelevel-defaults."2.13";
              compilerPlugins = [ registry.polyvariant.better-tostring ];
            };

          typelevel.cats-kernel =
            let
              # The app that generates the boilerplate
              boiler-app = pkgs.scala-tools.mkScalaApp {
                package = pkgs.scala-tools.mkScalacDerivation {
                  pname = "cats-kernel-boiler";
                  version = catsVersion;
                  src = cats-src;
                  sourceDirectories = [
                    ./boiler/shared.scala
                    ./boiler/KernelBoilerMain.scala
                    "project/KernelBoiler.scala"
                  ];
                  scalacOptions = sbt-typelevel-defaults."2.13";
                }
                ;
                mainClass = "KernelBoilerMain";
              };

              # The actual boilerplate sources
              boiler = pkgs.runCommand "cats-kernel-boiler" { buildInputs = [ boiler-app ]; } ''
                cats-kernel-boiler-app
                cp -r target $out
              '';
            in
            pkgs.scala-tools.mkScalacDerivation {
              pname = "cats-kernel";
              src = cats-src;
              version = catsVersion;
              sourceDirectories = [ "kernel/src/main/scala" "kernel/src/main/scala-2.13+" boiler ];
              scalacOptions = sbt-typelevel-defaults."2.13";
            };

          typelevel.cats-core =
            let
              binary = pkgs.scala-tools.fetchMavenArtifact {
                version = catsVersion;
                pname = "cats-core";
                artifact = "cats-core_2.13";
                org = [ "org" "typelevel" ];
                sha256 = "0njnf0w63l91ix7kpd27y9w3ki13phghm5dj5185rskxk14ynjqs";
                propagatedBuildInputs = [
                  registry.typelevel.cats-kernel
                ];
              };
              fromSource =
                let
                  # The app that generates the boilerplate
                  boiler-app = pkgs.scala-tools.mkScalaApp {
                    package = pkgs.scala-tools.mkScalacDerivation {
                      pname = "cats-core-boiler";
                      version = catsVersion;
                      src = cats-src;
                      sourceDirectories = [
                        ./boiler/shared.scala
                        ./boiler/CoreBoilerMain.scala
                        "project/Boilerplate.scala"
                        "project/TupleBifunctorInstancesBoiler.scala"
                        "project/TupleBitraverseInstancesBoiler.scala"
                        "project/TupleMonadInstancesBoiler.scala"
                        "project/TupleShowInstancesBoiler.scala"
                        "project/TupleUnorderedFoldableInstancesBoiler.scala"
                      ];
                      scalacOptions = sbt-typelevel-defaults."2.13";
                    };
                    mainClass = "CoreBoilerMain";
                  };

                  # The actual boilerplate sources
                  boiler = pkgs.runCommand "cats-core-boiler" { buildInputs = [ boiler-app ]; } ''
                    cats-core-boiler-app
                    cp -r target $out
                  '';
                in
                pkgs.scala-tools.mkScalacDerivation {
                  pname = "cats-core";
                  src = cats-src;
                  version = catsVersion;
                  sourceDirectories = [
                    "core/src/main/scala"
                    "core/src/main/scala-2"
                    "core/src/main/scala-2.13+"
                    boiler
                  ];
                  scalacOptions = sbt-typelevel-defaults."2.13";
                  compilerPlugins = [ registry.typelevel.kind-projector ];
                  buildInputs = [ registry.typelevel.cats-kernel ];
                };
            in
            { inherit binary fromSource; };

          typelevel.kind-projector =
            let version = "0.13.2"; in
            pkgs.scala-tools.mkScalacDerivation {
              pname = "kind-projector";
              inherit version;
              src = pkgs.fetchFromGitHub {
                owner = "typelevel";
                repo = "kind-projector";
                rev = "v${version}";
                sha256 = "sha256-k1ApAr22yjW1HMA56O4+QVM1qirYzmX0uSxc8lGyyyE=";
              };
              sourceDirectories = [
                "src/main/scala"
                "src/main/scala-newParser"
                "src/main/scala-newReporting"
              ];
              resourceDirectories = [ "src/main/resources" ];
              scalacOptions = sbt-typelevel-defaults."2.13";
            };

          typelevel.cats-effect =
            let
              version = "3.4.1";
              src = pkgs.fetchFromGitHub {
                owner = "typelevel";
                repo = "cats-effect";
                rev = "v${version}";
                sha256 = "sha256-UpbSmePobnShhiJrV0GN6bxqosaX9YPEYPvRRfykLbY";
              };
            in
            rec {
              kernel = pkgs.scala-tools.mkScalacDerivation {
                pname = "cats-effect-kernel";
                inherit version src;
                sourceDirectories = [
                  "kernel/jvm/src/main/scala"
                  "kernel/jvm-native/src/main/scala"
                  "kernel/shared/src/main/scala"
                  "kernel/shared/src/main/scala-2.13"
                ];
                buildInputs = [ registry.typelevel.cats-core.fromSource ];
                compilerPlugins = [ registry.typelevel.kind-projector ];
                scalacOptions = sbt-typelevel-defaults."2.13";
              };
              std = pkgs.scala-tools.mkScalacDerivation {
                pname = "cats-effect-std";
                inherit version src;
                sourceDirectories = [
                  "std/jvm/src/main/scala"
                  "std/jvm-native/src/main/scala"
                  "std/shared/src/main/scala"
                ];
                buildInputs = [ kernel ];
                compilerPlugins = [ registry.typelevel.kind-projector ];
                scalacOptions = sbt-typelevel-defaults."2.13";
              };
              core = pkgs.scala-tools.mkScalacDerivation {
                pname = "cats-effect";
                inherit version src;
                sourceDirectories = [
                  "core/jvm/src/main/java"
                  "core/jvm/src/main/scala"
                  "core/jvm-native/src/main/scala"
                  "core/shared/src/main/scala"
                ];
                buildInputs = [ kernel std ];
                compilerPlugins = [ registry.typelevel.kind-projector ];
                scalacOptions = sbt-typelevel-defaults."2.13";
              };
            };
          scala.collection-compat.binary = pkgs.scala-tools.fetchMavenArtifact {
            version = "2.8.1";
            pname = "scala-collection-compat";
            artifact = "scala-collection-compat_2.13";
            org = [ "org" "scala-lang" "modules" ];
            sha256 = "sha256:1704dq8x3agad1rv1i72fy3zwmfnk4j3hl0rfpz16n5bil1cd34v";
          };
          smithy4s.core.binary = pkgs.scala-tools.fetchMavenArtifact {
            version = "0.16.10";
            pname = "smithy4s-core";
            artifact = "smithy4s-core_2.13";
            org = [ "com" "disneystreaming" "smithy4s" ];
            sha256 = "02z651q6prw0rbrs0q0fwsazxbl264vibm0zy7aaipdqj5a9fnpl";
            propagatedBuildInputs = [
              registry.scala.collection-compat.binary
            ];
          };
        };

      in
      {
        packages.default = pkgs.scala-tools.mkScalaApp {
          package = pkgs.scala-tools.mkScalacDerivation {
            pname = "example";
            version = "0.0.0";
            src = ./example/src;
            sourceDirectories = [
              "."
              (smithy4s-nix.lib.${system}.smithy4sGenerate {
                pname = "smithy-sources";
                version = "0.0.0";
                specs = [ ./example/smithy ];
              })
            ];
            buildInputs = [
              registry.polyvariant.colorize-scala
              registry.typelevel.cats-effect.core
              registry.smithy4s.core.binary
            ];
            compilerPlugins = [
              registry.polyvariant.better-tostring
            ];
            scalacOptions = sbt-typelevel-defaults."2.13";
          };
          mainClass = "example.Main";
        };

        checks = self.packages.${system};
      }
    );
}
