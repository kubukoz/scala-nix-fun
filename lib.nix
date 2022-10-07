final: prev:
let
  pkgs = prev;

  scala-library = pkgs.runCommand "scala-library-${pkgs.scala.version}" { } ''
    mkdir -p $out/share/java
    cp ${pkgs.scala}/lib/scala-library.jar $out/share/java/scala-library.jar
  '';


  mkScalacDerivation =
    { pname
    , version
    , src
    , sourceDirectories ? [ ]
    , scalacOptions ? [ ]
    , buildInputs ? [ ]
    , resourceDirectories ? [ ]
    , compilerPlugins ? [ ]
    }@args:
    let
      isDir = path:
        let
          base = baseNameOf path;
          type = (builtins.readDir (dirOf path)).${base} or null;
        in
        type == "directory";

      listFilesOrGet = path:
        if isDir path then
          pkgs.lib.filesystem.listFilesRecursive path
        else [ path ];

      params = scalacOptions ++ builtins.map (p: "-Xplugin:${p}/share/java/${p.pname}.jar") compilerPlugins;

      finalArgs = {
        name = "${pname}-${version}";
        buildInputs = [ pkgs.scala pkgs.strip-nondeterminism pkgs.tree pkgs.rsync ];
        # todo rename arg
        propagatedBuildInputs = buildInputs ++ [ scala-library ];

        inherit sourceDirectories resourceDirectories params;

        buildPhase = ''
          source_paths=$(find $sourceDirectories -type f)
          mkdir scala-out

          echo "source paths: $source_paths"
          scalac $source_paths $params -d scala-out

          mkdir out

          java_sources=$(find $sourceDirectories -type f -name "*.java")
          if [ -n "$java_sources" ]; then
            # If there are any Java sources, now we need to generate classes for them.
            # This should see the classfiles generated by Scalac, so we're adding that as the CP.
            javac $java_sources -d out -cp scala-out
          fi

          # after java is done, we can copy scala stuff to the shared output dir
          rsync -a scala-out/* out/

        '';

        installPhase = ''

          for resourceDir in $resourceDirectories; do
            cp -r $resourceDir/* out
          done

          cd out
          echo "class paths"
          tree
          jar cf result.jar *
          strip-nondeterminism result.jar
          mkdir -p $out/share/java
          cp result.jar $out/share/java/${pname}.jar
        '';
      } // (builtins.removeAttrs args [ "buildInputs" ]);
    in

    pkgs.stdenv.mkDerivation finalArgs;

  mkScalaApp = { package ? [ ], mainClass }: pkgs.stdenv.mkDerivation
    {
      name = package.pname + "-app";
      buildInputs = [ pkgs.jre pkgs.makeWrapper package ];
      buildPhase = ''
        mkdir -p $out/bin
        makeWrapper ${pkgs.jre}/bin/java $out/bin/$name --add-flags "-cp $CLASSPATH ${mainClass}"
      '';
      dontUnpack = true;
      installPhase = "true";
    };

  fetchMavenArtifact =
    { version
    , pname
    , artifact
    , org
    , sha256
    , propagatedBuildInputs ? [ ]
    }:
    let url = "https://repo1.maven.org/maven2/${builtins.concatStringsSep "/" org}/${artifact}/${version}/${artifact}-${version}.jar"; in
    pkgs.stdenv.mkDerivation {
      inherit pname version;
      src = builtins.fetchurl {
        inherit url sha256;
      };
      buildInputs = [ pkgs.jre ];
      propagatedBuildInputs = propagatedBuildInputs ++ [ scala-library ];
      buildPhase = ''
        mkdir -p $out/share/java
        cp $src $out/share/java/$pname.jar
      '';
      dontUnpack = true;
      installPhase = "true";
    };

in
{ scala-tools = { inherit mkScalacDerivation mkScalaApp fetchMavenArtifact; }; }
