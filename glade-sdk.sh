#!/bin/bash

export GITLAB_ACCESS_TOKEN=glpat-PAc5ewpc8YaE3BqkB7m1

function usage() {
  echo "Usage: glade-ctl COMMAND [PROJECT_NAME] [BRANCH_NAME]"
  echo ""
  echo "Commands:"
  echo "  init                                    create necessary folders and pull project codes to their respective folders"
  echo "  build-image [PROJECT_NAME]              build container images for all the projects or specific projects"
  echo "  up                                      launch all services in docker containers"
  echo "  down                                    bring down all running containers"
  echo "  switch [PROJECT_NAME] [BRANCH_NAME]     switch projects to the specified branch"
  echo "  pull [PROJECT_NAME] [BRANCH_NAME]       git-pull from remote for all projects"
  echo "  add  [PROJECT_NAME]                     stage all changes in the current project directory"
  echo "  push [PROJECT_NAME] [BRANCH_NAME]       push all changes to remote git repository"
}



function init() {
  # Function to install figlet based on the package manager
  install_figlet() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
      # Install figlet using brew on Mac OS
      brew install figlet
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
      # Install figlet using apt on Linux
      sudo apt-get update
      sudo apt-get install figlet
    else
      # Unsupported operating system
      echo "Unsupported operating system. Unable to install figlet."
      exit 1
    fi
  }

  # Check if figlet is installed
  if ! [ -x "$(command -v figlet)" ]; then
    # Prompt the user to install figlet
    read -p "Figlet is needed to run, do you accept? (y/n) " answer
    if [[ $answer == "y" ]]; then
      install_figlet
    else
      # Exit the script if the user chooses not to install figlet
      exit 1
    fi
  fi

  # Function to install jq if not already installed
  install_jq() {
    if ! [ -x "$(command -v jq)" ]; then
      if [[ "$OSTYPE" == "darwin"* ]]; then
        # Install jq using brew on Mac OS
        brew install jq
      elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Install jq using apt on Linux
        sudo apt-get update
        sudo apt-get install jq
      else
        # Unsupported operating system
        echo "Unsupported operating system. Unable to install jq."
        exit 1
      fi
    fi
  }

  # Install jq
  install_jq

  echo "Welcome to the Glade command line tool!"
  # Draw Glade-ctl logo
  figlet Glade-ctl

  
  if [ ! -d "project-files" ]; then
    mkdir project-files
    cd project-files
    git init
  else
    cd project-files
  fi

  if [ -z "$GITLAB_ACCESS_TOKEN" ]; then
    echo "Error: GitLab access token is not set."
    exit 1
  fi

  # Get a list of GitLab projects using the API
  echo "Retrieving list of projects from GitLab..."
  response=$(curl --silent --header "PRIVATE-TOKEN: $GITLAB_ACCESS_TOKEN" "https://git.glade.ng/api/v4/projects?per_page=100&owned=true&membership=true")
  if [ -z "$response" ]; then
    echo "Error: Failed to retrieve projects from GitLab."
    exit 1
  fi


  # Parse the JSON response to get the project names, URLs, and IDs
  project_names=($(echo $response | jq -r '.[].name'))
  project_ssh_urls=($(echo $response | jq -r '.[].ssh_url_to_repo'))
  project_ids=($(echo $response | jq -r '.[].id'))

  # Prompt the user to select a project
  echo "Which project would you like to initialize?"
  for i in "${!project_names[@]}"; do
    echo "$(($i+1)). ${project_names[$i]}"
  done
  read -p "Enter the number of the project to clone: " project_index
  if ! [[ "$project_index" =~ ^[0-9]+$ ]] || [ "$project_index" -lt 1 ] || [ "$project_index" -gt "${#project_names[@]}" ]; then
    echo "Error: Invalid project number."
    exit 1
  fi
  selected_project=${project_names[$(($project_index-1))]}
  selected_project_ssh_url=${project_ssh_urls[$(($project_index-1))]}
  selected_project_id=${project_ids[$(($project_index-1))]}

  if [ -d "$selected_project" ]; then
    echo "Error: Project directory already exists."
    exit 1
  fi

  if ! echo "${project_names[@]}" | grep -q "\b$selected_project\b"; then
    echo "Error: Project does not exist in GitLab."
    exit 1
  fi

  # Clone the selected project
  git clone $selected_project_ssh_url
  cd $selected_project
}


function build-image() {
  if [ -z "$1" ]; then
    docker-compose build
  else
    # Check if the specified project exists in docker-compose.yml
    if grep -q "$1" docker-compose.yml; then
      docker-compose build $1
    elif grep -q "$selected_project" docker-compose.yml; then
      docker-compose build $selected_project
    else
      echo "Error: Project $1 not found in docker-compose.yml"
      exit 1
    fi
  fi
}

function up() {
  if [ ! -f "project-files/docker-compose.yml" ]; then
    echo "Error: docker-compose.yml not found in project directory."
    exit 1
  fi
  
  cd project-files
  docker-compose up
  cd ..
}

function down() {
  if [ ! -f "project-files/docker-compose.yml" ]; then
    echo "Error: docker-compose.yml not found in project directory."
    exit 1
  fi
  
  cd project-files
  docker-compose down
  cd ..
}

function switch() {
  if [ -z "$1" ]; then
    echo "No project name specified"
    return 1
  fi
  
  if [ ! -d "project-files/$1" ]; then
    echo "Project directory not found: $1"
    return 1
  fi
  
  cd "project-files/$1"
  
  if [ ! -d ".git" ]; then
    git init
  fi
  
  if [ -z "$2" ]; then
    git checkout master && echo "Switched to branch master"
  else
    git checkout "$2" && echo "Switched to branch $2"
  fi
  
  cd - > /dev/null
}


function pull() {
  if [ ! -d "project-files/$1" ]; then
    echo "Project directory not found: $1"
    return 1
  fi

  cd "project-files/$1" || exit
  git pull origin "$2" --allow-unrelated-histories
  cd - || exit
}


function add() {
  if [ ! -d "project-files/$1" ]; then
    echo "Project directory not found: $1"
    return 1
  fi

  cd "project-files/$1" || exit
  git add .
  cd - || exit
}

function push() {
  if [ ! -d "project-files/$1" ]; then
    echo "Project directory not found: $1"
    return 1
  fi

  cd "project-files/$1" || exit
  git push origin "$2"
  cd - || exit
}


case "$1" in
  "init")
    init
    ;;
  "build-image")
    build-image $2
    ;;
  "up")
    up
    ;;
  "down")
    down
    ;;
  "switch")
    switch $2 $3
    ;;
  "pull")
    pull $2
    ;;
  "db-reload")
    db-reload
    ;;
  *)
    usage
    exit 1
esac
