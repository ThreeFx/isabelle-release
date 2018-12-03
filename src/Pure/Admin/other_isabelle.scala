/*  Title:      Pure/Admin/other_isabelle.scala
    Author:     Makarius

Manage other Isabelle distributions.
*/

package isabelle


object Other_Isabelle
{
  def apply(isabelle_home: Path,
      isabelle_identifier: String = "",
      user_home: Path = Path.explode("$USER_HOME"),
      progress: Progress = No_Progress): Other_Isabelle =
    new Other_Isabelle(isabelle_home, isabelle_identifier, user_home, progress)
}

class Other_Isabelle(
  val isabelle_home: Path,
  val isabelle_identifier: String,
  user_home: Path,
  progress: Progress)
{
  other_isabelle =>

  override def toString: String = isabelle_home.absolute.toString

  if (proper_string(System.getenv("ISABELLE_SETTINGS_PRESENT")).isDefined)
    error("Cannot initialize with enclosing ISABELLE_SETTINGS_PRESENT")


  /* static system */

  def bash(
      script: String,
      redirect: Boolean = false,
      echo: Boolean = false,
      strict: Boolean = true): Process_Result =
    progress.bash(
      "export USER_HOME=" + File.bash_path(user_home) + "\n" +
      Isabelle_System.export_isabelle_identifier(isabelle_identifier) + script,
      env = null, cwd = isabelle_home.file, redirect = redirect, echo = echo, strict = strict)

  def apply(
      cmdline: String,
      redirect: Boolean = false,
      echo: Boolean = false,
      strict: Boolean = true): Process_Result =
    bash("bin/isabelle " + cmdline, redirect = redirect, echo = echo, strict = strict)

  def resolve_components(echo: Boolean): Unit =
    other_isabelle("components -a", redirect = true, echo = echo).check

  def getenv(name: String): String =
    other_isabelle("getenv -b " + Bash.string(name)).check.out

  val isabelle_home_user: Path = Path.explode(getenv("ISABELLE_HOME_USER"))

  val etc: Path = isabelle_home_user + Path.explode("etc")
  val etc_settings: Path = etc + Path.explode("settings")
  val etc_preferences: Path = etc + Path.explode("preferences")

  def copy_fonts(target_dir: Path): Unit =
    Isabelle_Fonts.make_entries(getenv = getenv(_), hidden = true).
      foreach(entry => File.copy(entry.path, target_dir))


  /* components */

  def init_components(
    base: Option[Path] = None,
    catalogs: List[String] = Nil,
    components: List[String] = Nil): List[String] =
  {
    val base_dir = base getOrElse Components.contrib(isabelle_home_user.absolute.dir)
    val dir = Components.admin(isabelle_home.absolute)
    catalogs.map(name =>
      "init_components " + File.bash_path(base_dir) + " " + File.bash_path(dir + Path.basic(name))) :::
    components.map(name =>
      "init_component " + File.bash_path(base_dir + Path.basic(name)))
  }


  /* settings */

  def clean_settings(): Boolean =
    if (!etc_settings.is_file) true
    else if (File.read(etc_settings).startsWith("# generated by Isabelle")) {
      etc_settings.file.delete; true
    }
    else false

  def init_settings(settings: List[String])
  {
    if (!clean_settings())
      error("Cannot proceed with existing user settings file: " + etc_settings)

    Isabelle_System.mkdirs(etc_settings.dir)
    File.write(etc_settings,
      "# generated by Isabelle " + Date.now() + "\n" +
      "#-*- shell-script -*- :mode=shellscript:\n" +
      settings.mkString("\n", "\n", "\n"))
  }


  /* cleanup */

  def cleanup()
  {
    clean_settings()
    etc.file.delete
    isabelle_home_user.file.delete
  }
}
