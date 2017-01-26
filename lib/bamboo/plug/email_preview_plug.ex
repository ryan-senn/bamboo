defmodule Bamboo.EmailPreviewPlug do
  use Plug.Router
  require EEx
  alias Bamboo.SentEmail

  EEx.function_from_file(:defp, :no_emails, Path.join(__DIR__, "no_emails.html.eex"))
  EEx.function_from_file(:defp, :index, Path.join(__DIR__, "index.html.eex"), [:assigns])
  EEx.function_from_file(:defp, :not_found, Path.join(__DIR__, "email_not_found.html.eex"), [:assigns])

  @moduledoc """
  A plug that can be used in your router to see delivered emails.

  This plug allows you to view all delivered emails. To see emails you must use
  the `Bamboo.LocalAdapter`.

  ## Using with Plug or Phoenix

      # Make sure you are using Bamboo.LocalAdapter in your config
      config :my_app, MyApp.Mailer,
        adapter: Bamboo.LocalAdapter

      # In your Router
      defmodule MyApp.Router do
        use Phoenix.Router # or use Plug.Router if you're not using Phoenix

        if Mix.env == :dev do
          # If using Phoenix
          forward "/sent_emails", Bamboo.EmailPreviewPlug

          # If using Plug.Router, make sure to add the `to`
          forward "/sent_emails", to: Bamboo.EmailPreviewPlug
        end
      end

  Now if you visit your app at `/sent_emails` you will see a list of delivered
  emails.
  """

  plug :match
  plug :dispatch

  get "/" do
    if Enum.empty?(all_emails()) do
      conn |> render(:ok, no_emails())
    else
      conn |> render_index(newest_email())
    end
  end

  get "/:id" do
    if email = SentEmail.get(id) do
      conn |> render_index(email)
    else
      conn |> render_not_found
    end
  end

  get "/:id/html" do
    if email = SentEmail.get(id) do
      conn
      |> Plug.Conn.put_resp_content_type("text/html")
      |> send_resp(:ok, email.html_body || "")
    else
      conn
      |> Plug.Conn.put_resp_content_type("text/html")
      |> render_not_found
    end
  end

  defp render_not_found(conn) do
    assigns = %{ base_path: base_path(conn) }
    render(conn, :not_found, not_found(assigns))
  end

  defp render_index(conn, email) do
    assigns = %{
      conn: conn,
      base_path: base_path(conn),
      emails: all_emails(),
      selected_email: email
    }
    render(conn, :ok, index(assigns))
  end

  defp all_emails do
    SentEmail.all
  end

  defp newest_email do
    all_emails() |> List.first
  end

  defp render(conn, status, rendered_template) do
    send_resp(conn, status, rendered_template)
  end

  defp base_path(%{script_name: []}), do: ""
  defp base_path(%{script_name: script_name}) do
    "/" <> Enum.join(script_name, "/")
  end
end
