{
  inputs.nixpkgs.url = "github:nixos/nixpkgs";
  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs = { self, nixpkgs, flake-utils, ... }@inputs:
    flake-utils.lib.eachSystem [ "x86_64-linux" "x86_64-darwin" "aarch64-linux" "aarch64-darwin" ] (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ (import ./lib.nix) ];
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
        catsVersion = "2.8.0";
        cats-src = pkgs.fetchFromGitHub {
          owner = "typelevel";
          repo = "cats";
          rev = "v${catsVersion}";
          sha256 = "sha256-/oplCnPUS+MMF0L/bE6DVKVTmEmhlJZJqM7iPrbJLxE=";
        };

        registry = {
          polyvariant.colorize-scala =
            let version = "0.2.0"; in
            pkgs.scala-tools.mkScalacDerivation {
              pname = "colorize-scala";
              inherit version;
              src = pkgs.fetchFromGitHub {
                owner = "polyvariant";
                repo = "colorize-scala";
                rev = "v${version}";
                sha256 = "sha256-eZaoqHLBcXGa4uvi/6yeJlcyVyhlaEE+YlSkcKkh4cQ=";
              };
              sourceDirectories = [ "core/shared/src/main/scala" ];
              scalacOptions = sbt-typelevel-defaults."2.13";
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
                sha256 = "sha256:0shl38abiywr6mcdw3vfj7ck45fsqn0l6s2ypqpz100wfx1b55rk";
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
            };

          typelevel.cats-effect =
            let
              version = "3.3.14";
              src = pkgs.fetchFromGitHub {
                owner = "typelevel";
                repo = "cats-effect";
                rev = "v${version}";
                sha256 = "sha256-AYZSfSHEZCeADR1e/oSbP26CWC6KG0T9XD1yhGT9ITY=";
              };
            in
            rec {
              kernel = pkgs.scala-tools.mkScalacDerivation {
                pname = "cats-effect-kernel";
                inherit version src;
                sourceDirectories = [
                  "kernel/jvm/src/main/scala"
                  "kernel/shared/src/main/scala"
                ];
                buildInputs = [ registry.typelevel.cats-core.fromSource ];
                compilerPlugins = [ registry.typelevel.kind-projector ];
              };
              std = pkgs.scala-tools.mkScalacDerivation {
                pname = "cats-effect-std";
                inherit version src;
                sourceDirectories = [
                  "std/jvm/src/main/scala"
                  "std/shared/src/main/scala"
                ];
                buildInputs = [ kernel ];
                compilerPlugins = [ registry.typelevel.kind-projector ];
              };
              core = pkgs.scala-tools.mkScalacDerivation {
                pname = "cats-effect";
                inherit version src;
                sourceDirectories = [
                  "core/jvm/src/main/java"
                  "core/jvm/src/main/scala"
                  "core/shared/src/main/scala"
                  "core/shared/src/main/scala-2"
                ];
                buildInputs = [ kernel std ];
                compilerPlugins = [ registry.typelevel.kind-projector ];
              };
            };
        };

      in
      {
        packages.default = pkgs.scala-tools.mkScalaApp {
          package = pkgs.scala-tools.mkScalacDerivation {
            pname = "example";
            version = "0.0.0";
            src = ./example/src;
            sourceDirectories = [ "." ];
            buildInputs = [
              registry.polyvariant.colorize-scala
              registry.typelevel.cats-effect.core
            ];
          };
          mainClass = "example.Main";
        };
      }
    );
}
