/*  Title:      Pure/PIDE/editor.scala
    Author:     Makarius

General editor operations.
*/

package isabelle


abstract class Editor[Context]
{
  def session: Session
  def current_context: Context
  def current_node(context: Context): Option[Document.Node.Name]
  def current_snapshot(context: Context): Option[Document.Snapshot]
  def current_command(context: Context, snapshot: Document.Snapshot): Option[(Command, Text.Offset)]
}

