#!/bin/bash

# Copyright (C) 2026 Diwas Neupane
# SPDX-License-Identifier: Apache-2.0
# Fedora Set Up Script

# *******************************************************************************
# - Script to generate an SSH key for connection and, a GPG key for security.
# - Upgrades Fedora packages and, installs vim, git, openssh, gnupg, etc. packages.
# - Generates an SSH key as well as a GPG key for adding them to GitHub's account.
# - Author: Diwas Neupane (techdiwas)
# - Version: fedora:1.0
# - Date: 20231225
# - Last modified: 20260718
#
#        - Changes for (20230802)  - make it clear that this script is not ready.
#        - Changes for (20230803)  - make it clear that this script is ready.
#        - Changes for (20231020)  - generate an SSH key and, a GPG key by following official method guided by GitHub.
#        - Changes for (20231020)  - support for creating and, restoring backup.
#        - Changes for (20231224)  - support to restore gnupg files even if system is fresh.
#        - Changes for (20231225)  - separately back up and restore ssh and gpg keys.
#        - Changes for (20250606)  - introduce email and username validation. Also, improved overall script.
#        - Changes for (20250701)  - set up gh for login into user's GitHub account and nano as a default editor for git.
#        - Changes for (20250705)  - auto copy required files from Downloads folder for restoring purposes.
#        - Changes for (20250811)  - edit shell profile settings (used for Ubuntu).
#        - Changes for (20250911)  - clone SSH and GPG keys from GitHub repository and perform misc changes.
#        - Changes for (20260718)  - ported from Ubuntu/apt to Fedora/dnf (package names, gh install, repo file).
#
# *******************************************************************************

# edit shell profile settings
change_settings() {
    local input;
    echo "-- Change shell profile settings (~/.bashrc) ? [Y/n]"
    read input;
    if [ "$input" = 'Y' ] || [ "$input" = 'y' ]; then
        nano ~/.bashrc;
        source ~/.bashrc;
    fi
}

# check whether the Downloads directory exists or not
setup_storage() {
    if [ -d "$HOME/Downloads" ]; then
        echo "-- Downloads directory exists. No need to create it.";
    else
        echo "-- Downloads directory is missing.";
        echo "-- Creating Downloads directory...";
        mkdir -p "$HOME/Downloads";
        echo "-- Downloads directory created at $HOME/Downloads.";
    fi
}

# configure dnf repos (Fedora has no single sources.list; each repo is its own
# file under /etc/yum.repos.d/. This opens the main Fedora repo file — for a
# specific third-party repo, edit its .repo file in that directory instead.)
setup_repo() {
    echo "-- Opening /etc/yum.repos.d/fedora.repo for editing...";
    echo "-- (Other repos live as separate .repo files in /etc/yum.repos.d/.)";
    sudo nano /etc/yum.repos.d/fedora.repo;
}

# validation of username and email
validate_email() {
    local email_regex="^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$";
    if [[ ! "$1" =~ $email_regex ]]; then
        echo "-- Invalid email address format. Please try again.";
        return 1;
    fi
    return 0;
}

check_inputs() {
  # required credentials
  echo "-- Enter your username:";
  read username;

  while true; do
      echo "-- Enter your email address:";
      read user_email;
      validate_email "$user_email" && break;
  done

  # extra packages
  echo "-- Do you want to install any other packages (Y/n)?";
  read input;
  if [ "$input" = 'y' ] || [ "$input" = 'Y' ]; then
      echo "-- Enter name of the package you want to install:";
      read package_name;
      extra_packages="$package_name";
  else
      extra_packages="";
  fi
}

# update Fedora's environment (dnf upgrade refreshes metadata and upgrades
# in one step, so there's no separate "update" call needed like with apt)
update_environment() {
  sudo dnf upgrade --refresh -y;
}

# install gh CLI (Fedora ships it directly in its own repos as of recent
# releases; the package there can trail upstream by a release or two — if
# you need the newest gh, add GitHub's repo instead, see https://cli.github.com/)
install_gh() {
  if rpm -q gh >/dev/null 2>&1; then
    echo "-- gh is already installed.";
    return 0;
  fi
  echo "-- Installing GitHub CLI from Fedora's repositories...";
  sudo dnf install -y gh;
  echo "-- gh has been installed.";
}

# install required packages
install_packages() {
  echo "-----------------------------------";
  echo "-- Installing required packages ...";
  echo "-----------------------------------";
  sudo dnf install -y git openssh-clients gnupg2 nano $extra_packages;
  install_gh;
  echo "-- Required packages have been installed.";
}

# make sure ~/.ssh exists with correct permissions (it's only auto-created
# once ssh-keygen or ssh has been run at least once, so a fresh Fedora
# install won't have it yet)
ensure_ssh_dir() {
  if [ ! -d "$HOME/.ssh" ]; then
      mkdir -p -m 700 "$HOME/.ssh";
      echo "-- Created $HOME/.ssh (did not exist).";
  fi
}

# generate an SSH key
generate_an_ssh_key() {
  echo "---------------------------------------";
  echo "-- Generating an SSH key for GitHub ...";
  echo "---------------------------------------";
  ensure_ssh_dir;
  if ssh-keygen -t ed25519 -C "$user_email"; then
      ssh_key="id_ed25519";
  else
      ssh-keygen -t rsa -b 4096 -C "$user_email";
      ssh_key="id_rsa";
  fi
  eval "$(ssh-agent -s)";
  ssh-add ~/.ssh/$ssh_key;
  echo "-- SSH key has been generated and, added to ssh-agent.";
}

# generate a GPG key
generate_a_gpg_key() {
  echo "--------------------------------------";
  echo "-- Generating a GPG key for GitHub ...";
  echo "--------------------------------------";
  gpg --full-generate-key;
  gpg --list-secret-keys --keyid-format=long;
  echo "-- Enter GPG key ID:";
  read gpg_key_id;
  gpg --armor --export $gpg_key_id > ~/.gnupg/id_gpg;
  # configure git for signing key
  git config --global commit.gpgsign true;
  git config --global user.signingkey $gpg_key_id;
  echo "-- GPG key has been generated and, exported.";
}

# configure git for an SSH key and, a GPG key
config_git_for_gpg_key() {
  echo "---------------------------------------";
  echo "-- Configuring git for your GPG key ...";
  echo "---------------------------------------";
  git config --global user.email "$user_email";
  git config --global user.name "$username";

  # set GPG_TTY environment variable to your `.bashrc` startup file
  [ -f ~/.bashrc ] || touch ~/.bashrc;
  # set GPG_TTY environment variable only if it's not already there
  if ! grep -qxF 'export GPG_TTY=$(tty)' ~/.bashrc; then
    echo -e '# Set `GPG_TTY` for GPG (GNU Privacy Guard) passphrase handling.\nexport GPG_TTY=$(tty)' >> ~/.bashrc;
    echo '-- Added GPG_TTY environment variable to `~/.bashrc`.';
  else
    echo '-- GPG_TTY environment variable already present in `~/.bashrc`, skipping...';
  fi
  source ~/.bashrc;
  echo "-- Git configuration completed. Additionally, GPG_TTY has been configured for seamless usage of GPG keys.";
}

# set `nano` as a default editor for git
config_editor() {
  git config --global core.editor "nano"
}

# login to user's GitHub account
config_gh() {
  # when gh is not installed, install it
  if rpm -q gh >/dev/null 2>&1; then
    echo "-- gh is installed.";
  else
    echo "-- gh is not installed.";
    echo "-- Installing gh...";
    install_gh;
  fi
  # login to user's GitHub account via gh
  gh auth login;
}

# show an SSH and a GPG public keys for adding them to GitHub account
show_ssh_and_gpg_public_keys() {
  echo "------------------------------------------";
  echo "-- Your SSH public key is displayed below:";
  echo "------------------------------------------";
  cat ~/.ssh/$ssh_key.pub;
  echo "";
  echo "------------------------------------------";
  echo "-- Your GPG public key is displayed below:";
  echo "------------------------------------------";
  cat ~/.gnupg/id_gpg;
  # cleanup junk
  rm ~/.gnupg/id_gpg;
}

# backup GPG key
backup_gpg_key() {
  echo "------------------------";
  echo "-- Backing up GPG key...";
  echo "------------------------";
  gpg --export --export-options backup --output ~/id_gpg_public $user_email;
  gpg --export-secret-keys --export-options backup --output ~/id_gpg_private;
  gpg --export-ownertrust > ~/gpg_ownertrust;
  cat ~/gpg_ownertrust;
  ls -a;
  echo "-- Back up completed.";
}

# backup SSH key
backup_ssh_key() {
  echo "------------------------";
  echo "-- Backing up SSH key...";
  echo "------------------------";
  if [ -f $HOME/.ssh/id_rsa ] && [ -f $HOME/.ssh/id_rsa.pub ]; then
      cp $HOME/.ssh/id_rsa $HOME/.ssh/id_rsa.pub $HOME;
      echo "-- SSH key backed up.";
  elif [ -f $HOME/.ssh/id_ed25519 ] && [ -f $HOME/.ssh/id_ed25519.pub ]; then
      cp $HOME/.ssh/id_ed25519 $HOME/.ssh/id_ed25519.pub $HOME;
      echo "-- SSH key backed up.";
  else
      echo "-- No existing SSH key found.";
  fi
  ls -a;
  echo "-- Back up completed.";
}

# if SSH and GPG keys are stored in GitHub repository then clone it
clone_github_repo() {
    local github_repo_name;
    local github_username;

    echo "-- GitHub Username ?";
    read github_username;
    echo "-- GitHub Reponame ?";
    read github_repo_name;

    sudo dnf check-update -y;
    # when git is not installed
    if rpm -q git >/dev/null 2>&1; then
      echo "-- git is installed.";
    else
      echo "-- git is not installed.";
      echo "-- Installing git...";
      sudo dnf install -y git;
    fi
    git clone https://github.com/"$github_username"/"$github_repo_name".git;

    if [ -f $github_repo_name/id_gpg_public ] && [ -f $github_repo_name/id_gpg_private ] && [ -f $github_repo_name/gpg_ownertrust ]; then
        cp $github_repo_name/id_gpg_public $github_repo_name/id_gpg_private $github_repo_name/gpg_ownertrust $HOME;
        echo "-- Files copied to $HOME.";
    else
        echo "-- No files found in $github_repo_name.";
        exit 1;
    fi
    if [ -f $github_repo_name/id_rsa ] && [ -f $github_repo_name/id_rsa.pub ]; then
        cp $github_repo_name/id_rsa $github_repo_name/id_rsa.pub $HOME;
        echo "-- Files copied to $HOME.";
    elif [ -f $github_repo_name/id_ed25519 ] && [ -f $github_repo_name/id_ed25519.pub ]; then
        cp $github_repo_name/id_ed25519 $github_repo_name/id_ed25519.pub $HOME;
        echo "-- Files copied to $HOME.";
    else
        echo "-- No files found in $github_repo_name.";
        exit 1;
    fi

    echo "-- Repository exists, so SSH and GPG keys are copied.";
    echo "-- Now, you can successfully restore SSH and GPG keys.";

    # cleanup repo
    rm -rf "$github_repo_name";
}

# restore GPG key
restore_gpg_key() {
  echo "--------------------";
  echo "-- Restoring GPG key";
  echo "--------------------";

  sudo dnf check-update -y;
  # when GNU Privacy Guard (gnupg2) is not installed
  if rpm -q gnupg2 >/dev/null 2>&1; then
    echo "-- GNU Privacy Guard (gnupg2) is installed.";
  else
    echo "-- GNU Privacy Guard (gnupg2) is not installed.";
    echo "-- Installing GNU Privacy Guard (gnupg2)...";
    sudo dnf install -y gnupg2;
  fi

  # assume files are in Downloads dir
  int_storage="$HOME/Downloads";
  # check if files are already in $HOME at first. (ref clone_github_repo)
  if [ -f $HOME/id_gpg_public ] && [ -f $HOME/id_gpg_private ] && [ -f $HOME/gpg_ownertrust ]; then
      echo "-- Files are in $HOME.";
  elif [ -f $int_storage/id_gpg_public ] && [ -f $int_storage/id_gpg_private ] && [ -f $int_storage/gpg_ownertrust ]; then
      cp $int_storage/id_gpg_public $int_storage/id_gpg_private $int_storage/gpg_ownertrust $HOME;
      echo "-- Files copied to $HOME.";
  else
      echo "-- No files found in $int_storage.";
      exit 1;
  fi

  if [ -f $HOME/id_gpg_public ] && [ -f $HOME/id_gpg_private ] && [ -f $HOME/gpg_ownertrust ]; then
      gpg --import ~/id_gpg_public;
      gpg --import ~/id_gpg_private;
      gpg --import ~/gpg_ownertrust;
  else
     echo "-- No files exist in $HOME to restore.";
     exit 1;
  fi

  gpg --list-secret-keys --keyid-format=long;
  echo "-- Enter GPG key ID:";
  read gpg_key_id;

  # Set up trust
  gpg --edit-key "$gpg_key_id";
  gpg --list-secret-keys --keyid-format=long;

  # configure git for signing key
  git config --global commit.gpgsign true;
  git config --global user.signingkey $gpg_key_id;
  echo "-- Restored.";

  # cleanup
  rm id_gpg_public id_gpg_private gpg_ownertrust;
}

# restore SSH key
restore_ssh_key() {
  echo "--------------------";
  echo "-- Restoring SSH key";
  echo "--------------------";

  sudo dnf check-update -y;
  # when OpenSSH client is not installed
  if rpm -q openssh-clients >/dev/null 2>&1; then
    echo "-- OpenSSH client is installed.";
  else
    echo "-- OpenSSH client is not installed.";
    echo "-- Installing OpenSSH client...";
    sudo dnf install -y openssh-clients;
  fi

  # assume files are in Downloads dir
  int_storage="$HOME/Downloads";
  # check if files are already in $HOME at first. (ref clone_github_repo)
  if [ -f $HOME/id_rsa ] && [ -f $HOME/id_rsa.pub ]; then
      echo "-- Files are in $HOME.";
  elif [ -f $HOME/id_ed25519 ] && [ -f $HOME/id_ed25519.pub ]; then
      echo "-- Files are in $HOME.";
  elif [ -f $int_storage/id_rsa ] && [ -f $int_storage/id_rsa.pub ]; then
      cp $int_storage/id_rsa $int_storage/id_rsa.pub $HOME;
      echo "-- Files copied to $HOME.";
  elif [ -f $int_storage/id_ed25519 ] && [ -f $int_storage/id_ed25519.pub ]; then
      cp $int_storage/id_ed25519 $int_storage/id_ed25519.pub $HOME;
      echo "-- Files copied to $HOME.";
  else
      echo "-- No files found in $int_storage.";
      exit 1;
  fi

  ensure_ssh_dir;
  if [ -f $HOME/id_rsa ] && [ -f $HOME/id_rsa.pub ]; then
      mv $HOME/id_rsa $HOME/id_rsa.pub $HOME/.ssh;
      chmod 600 $HOME/.ssh/id_rsa;
      chmod 644 $HOME/.ssh/id_rsa.pub;
      echo "-- SSH key restored.";
      eval "$(ssh-agent -s)";
      ssh-add ~/.ssh/id_rsa;
  elif [ -f $HOME/id_ed25519 ] && [ -f $HOME/id_ed25519.pub ]; then
      mv $HOME/id_ed25519 $HOME/id_ed25519.pub $HOME/.ssh;
      chmod 600 $HOME/.ssh/id_ed25519;
      chmod 644 $HOME/.ssh/id_ed25519.pub;
      echo "-- SSH key restored.";
      eval "$(ssh-agent -s)";
      ssh-add ~/.ssh/id_ed25519;
  else
      echo "-- No SSH key backup found.";
  fi
  echo "-- Restored.";
}

# do all the work!
WorkNow() {
    local SCRIPT_VERSION="20260718";
    local START=$(date);
    local STOP=$(date);
    echo "$0, v$SCRIPT_VERSION";
    check_inputs;
    echo "-- What do you want to do today ?";
    echo "-- Setup Fedora's Environment (s).";
    echo "-- Setup Fedora's Environment Plus Configure SSH And GPG Keys (ssg).";
    echo "-- Restore from GitHub (rgit).";
    echo "-- Restore SSH Key (rssh).";
    echo "-- Restore GPG Key (rgpg).";
    echo "-- Backup SSH Key (bssh).";
    echo "-- Backup GPG Key (bgpg).";
    read answer;
    case "$answer" in
        "bssh")
            backup_ssh_key;
            ;;
        "bgpg")
            backup_gpg_key;
            ;;
        "rgit")
            clone_github_repo;
            ;;
        "rssh")
            restore_ssh_key;
            ;;
        "rgpg")
            restore_gpg_key;
            config_git_for_gpg_key;
            config_editor;
            config_gh;
            ;;
        "s")
            change_settings;
            setup_storage;
            setup_repo;
            update_environment;
            install_packages;
            ;;
        "ssg")
            change_settings;
            setup_storage;
            setup_repo;
            update_environment;
            install_packages;
            config_gh;
            generate_an_ssh_key;
            generate_a_gpg_key;
            config_git_for_gpg_key;
            config_editor;
            show_ssh_and_gpg_public_keys;
            echo "-- Now, you can copy your SSH as well as GPG public keys and, add them to your GitHub's account.";
            ;;
          *)
            echo "-- Start time = $START";
            echo "-- Stop time = $STOP";
            exit 0;
            ;;
    esac
}

# --- main() ---
WorkNow;
# --- end main() ---
