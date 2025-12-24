defmodule MountainNerves.TelegramUsers do
  @moduledoc """
  The TelegramUsers context for managing Telegram user accounts.
  """

  import Ecto.Query, warn: false
  alias MountainNerves.Repo
  alias MountainNerves.TelegramUsers.TelegramUser

  @doc """
  Gets a telegram user by telegram_id.

  Returns nil if the user does not exist.

  ## Examples

      iex> get_by_telegram_id(123456789)
      %TelegramUser{}

      iex> get_by_telegram_id(999999999)
      nil

  """
  def get_by_telegram_id(telegram_id) do
    Repo.get(TelegramUser, telegram_id)
  end

  @doc """
  Creates or updates a telegram user.

  This function is idempotent - if a user with the given telegram_id already exists,
  it will update their information. Otherwise, it will create a new user.

  ## Examples

      iex> upsert_user(%{telegram_id: 123456789, username: "john_doe"})
      {:ok, %TelegramUser{}}

      iex> upsert_user(%{telegram_id: nil})
      {:error, %Ecto.Changeset{}}

  """
  def upsert_user(attrs) do
    case get_by_telegram_id(attrs[:telegram_id] || attrs["telegram_id"]) do
      nil ->
        %TelegramUser{}
        |> TelegramUser.changeset(attrs)
        |> Repo.insert()

      user ->
        user
        |> TelegramUser.changeset(attrs)
        |> Repo.update()
    end
  end

  @doc """
  Creates a telegram user.

  ## Examples

      iex> create_user(%{telegram_id: 123456789})
      {:ok, %TelegramUser{}}

      iex> create_user(%{telegram_id: nil})
      {:error, %Ecto.Changeset{}}

  """
  def create_user(attrs \\ %{}) do
    %TelegramUser{}
    |> TelegramUser.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a telegram user.

  ## Examples

      iex> update_user(user, %{username: "new_username"})
      {:ok, %TelegramUser{}}

      iex> update_user(user, %{telegram_id: nil})
      {:error, %Ecto.Changeset{}}

  """
  def update_user(%TelegramUser{} = user, attrs) do
    user
    |> TelegramUser.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Lists all telegram users.

  ## Examples

      iex> list_users()
      [%TelegramUser{}, ...]

  """
  def list_users do
    Repo.all(TelegramUser)
  end
end
