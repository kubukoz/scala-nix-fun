package sbt

// Polyfills for sbt that are enough to run boilerplate generators for Cats
import java.nio.file.Files
import java.nio.charset.StandardCharsets
import java.nio.file.Path
import java.nio.file.Paths

class File(val f: Path) {
  def /(child: String): File = new File(f.resolve(child))
}

object IO {
  def write(file: File, content: String): Unit = {
    file.f.getParent().toFile().mkdirs()
    Files.write(file.f, content.getBytes(StandardCharsets.UTF_8))
  }
}

object root extends File(Paths.get("."))
