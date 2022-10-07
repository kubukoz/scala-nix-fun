package example
object Main {
  import org.polyvariant.colorize._
  import cats.implicits._
  def main(args: Array[String]): Unit = {
    println(colorize"hello".red.render)
    println(1 |+| 10)
  }
}
