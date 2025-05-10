# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This project, `MySystem`, is a demonstration of Erlang/Elixir concepts from the "Soul of Erlang and Elixir" talk. It showcases several key features:

- Dynamic load control and monitoring of scheduler utilization
- Hot code reloading/upgrade while the system is running
- Distributed system capabilities with dynamic node addition
- Phoenix LiveView for real-time web interface

## Building and Running

### Setup Commands

```bash
# Install dependencies
mix deps.get

# Build the project and its assets
mix setup

# Build a production release
mix release

# Start the system
_build/prod/rel/my_system/bin/my_system start
```

### Development Commands

```bash
# Start the development server
mix phx.server

# Run tests
mix test

# Add a new node to handle load
mix add_node

# Upgrade running system with code changes 
mix upgrade
```

## System Architecture

The system consists of several key components:

1. **`MySystem.Math`** - A module providing a sum calculation function that runs in a separate process.

2. **`MySystem.LoadControl`** - Manages synthetic system load:
   - Controls number of active worker processes
   - Monitors scheduler utilization
   - Distributes load across available nodes
   - Collects metrics on worker success rates

3. **Web Interface** (`MySystemWeb`):
   - Main page (`/`): Provides a simple form to calculate sums
   - Load Control Dashboard (`/dashboard/load_control`): Allows controlling load and scheduler count
   - Process Dashboard (`/dashboard/processes`): Monitors processes and their resource usage

## Key Features

### Load Control System

The load control system demonstrates how to:
- Monitor scheduler utilization in real-time
- Dynamically adjust the number of active worker processes
- Distribute load across multiple nodes
- Visualize system performance metrics

### Hot Code Upgrading

The `mix upgrade` task demonstrates Erlang's hot code reloading capability:
- It connects to a running node
- Copies new beam files to the release
- Purges old code and loads new code without stopping the system

### Distributed System

The project can run as a distributed system:
- `mix add_node` starts additional nodes
- These nodes coordinate to distribute load
- Each node runs its own set of worker processes
- Communication happens via RPC and the Erlang distribution mechanism

## Web Endpoints

- Main page: `http://localhost:4000/` - Sum calculation
- Load Control: `http://localhost:4000/dashboard/load_control`
- Processes: `http://localhost:4000/dashboard/processes`