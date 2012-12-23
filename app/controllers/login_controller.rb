# encoding: utf-8
class LoginController < ApplicationController
  skip_before_filter :authenticate        # no authentication since this is the login page
  before_filter :validate_token, :only => [:new_password, :update_password]

  # Display the form to enter an email address requesting a token to set a new password.
  def forgot_password
    @user = User.new
  end
  
  # Sends an email to a user with the token that allows setting a new password through action "password".
  def reset_password
    if (user = User.find_by_email(params[:user][:email]))
      user.reset_password_token = user.new_random_password(16)
      user.reset_password_expires = Time.now.advance(:days => 2)
      if user.save
        Mailer.reset_password(user)
        logger.debug("Sent password reset email to #{user.email}.")
      end
    end
    redirect_to login_url, :notice => "Wenn Deine E-Mail hier registiert ist bekommst Du jetzt eine Nachricht mit einem Passwort-Zurücksetzen-Link."
  end
  
  # Set a new password with a token from the password reminder email.
  # Called with params :id => User.id and :token => User.reset_password_token to specify a new password.
  def new_password
  end
  
  # Sets a new password.
  # Called with params :id => User.id and :token => User.reset_password_token to specify a new password.
  def update_password
    @user.attributes = params[:user]
    if @user.valid?
      @user.reset_password_token = nil
      @user.reset_password_expires = nil
      @user.save
      redirect_to login_url, :notice => "Dein Passwort wurde aktualisiert. Du kannst Dich jetzt anmelden."
    else
      render :new_password
    end
  end

  # For invited users.
  def accept_invitation
    @invite = Invite.find_by_token(params[:token])
    if (@invite.nil? || @invite.expires_at < Time.now)
      flash[:error] = "Deine Einladung ist nicht (mehr) gültig."
      render :action => 'login'
    elsif @invite.group.nil?
      flash[:error] = "Die Gruppe, in die Du eingeladen wurdest, existiert leider nicht mehr."
      render :action => 'login'
    elsif (request.post?)
      User.transaction do
        @user = User.new(params[:user])
        @user.email = @invite.email
        if @user.save
          Membership.new(:user => @user, :group => @invite.group).save!
          @invite.destroy
          redirect_to login_url, notice: "Herzlichen Glückwunsch, Dein Account wurde erstellt. Du kannst Dich nun einloggen."
        end
      end
    else
      @user = User.new(:email => @invite.email)
    end
  rescue
    flash[:error] = "Ein Fehler ist aufgetreten. Bitte erneut versuchen."
  end

  protected

  def validate_token
    @user = User.find_by_id_and_reset_password_token(params[:id], params[:token])
    if (@user.nil? || @user.reset_password_expires < Time.now)
      flash.now.error = "Ungültiger oder abgelaufener Token. Bitte versuch es erneut."
      render :action => 'forgot_password'
    end
  end
end
