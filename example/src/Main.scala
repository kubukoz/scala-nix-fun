package example

import org.polyvariant.colorize._
import cats.implicits._
import cats.effect._

object Main extends IOApp.Simple {
  def run = {
    IO.println(colorize"hello".red.render) *>
      IO.println(1 |+| 10)
  }
}
