"""Command-line interface for managing pyshim configuration."""

import argparse
import sys
from pathlib import Path

from .config import Config
from .context import ContextDetector
from . import __version__


def cmd_config_add(args):
    """Add a Python interpreter to configuration."""
    config = Config()
    try:
        config.add_interpreter(args.name, args.path)
        print(f"Added interpreter '{args.name}': {args.path}")
        return 0
    except ValueError as e:
        print(f"Error: {e}", file=sys.stderr)
        return 1


def cmd_config_remove(args):
    """Remove a Python interpreter from configuration."""
    config = Config()
    config.remove_interpreter(args.name)
    print(f"Removed interpreter '{args.name}'")
    return 0


def cmd_config_list(args):
    """List all configured Python interpreters."""
    config = Config()
    interpreters = config.list_interpreters()
    
    if not interpreters:
        print("No interpreters configured.")
        return 0
    
    default = config._config.get("default_interpreter")
    
    print("Configured Python interpreters:")
    for name, path in interpreters.items():
        marker = " (default)" if name == default else ""
        exists = "✓" if Path(path).exists() else "✗"
        print(f"  [{exists}] {name}: {path}{marker}")
    
    return 0


def cmd_config_default(args):
    """Set the default Python interpreter."""
    config = Config()
    try:
        config.set_default_interpreter(args.name)
        print(f"Set '{args.name}' as default interpreter")
        return 0
    except ValueError as e:
        print(f"Error: {e}", file=sys.stderr)
        return 1


def cmd_which(args):
    """Show which Python interpreter would be used."""
    config = Config()
    context = ContextDetector(config)
    
    interpreter = context.resolve_interpreter()
    
    if not interpreter:
        print("No Python interpreter configured", file=sys.stderr)
        return 1
    
    print(interpreter)
    return 0


def cmd_status(args):
    """Show current pyshim status and configuration."""
    config = Config()
    context = ContextDetector(config)
    
    print(f"pyshim version: {__version__}")
    print(f"Config directory: {config.config_dir}")
    print()
    
    # Show current interpreter
    interpreter = context.resolve_interpreter()
    if interpreter:
        print(f"Current interpreter: {interpreter}")
    else:
        print("Current interpreter: None configured")
    
    print()
    
    # Show detection details
    venv = context.detect_virtual_environment()
    if venv:
        print(f"Virtual environment: {venv}")
    
    version_file = context.detect_python_version_file()
    if version_file:
        print(f".python-version found: {version_file}")
    
    default = config.get_default_interpreter()
    if default:
        print(f"Default interpreter: {default}")
    
    return 0


def main():
    """Main entry point for pyshim CLI."""
    parser = argparse.ArgumentParser(
        description="pyshim - Context-aware Python shim for Windows"
    )
    parser.add_argument(
        "--version",
        action="version",
        version=f"pyshim {__version__}"
    )
    
    subparsers = parser.add_subparsers(dest="command", help="Commands")
    
    # config command
    config_parser = subparsers.add_parser("config", help="Manage configuration")
    config_subparsers = config_parser.add_subparsers(dest="config_command")
    
    # config add
    add_parser = config_subparsers.add_parser("add", help="Add Python interpreter")
    add_parser.add_argument("name", help="Name for the interpreter")
    add_parser.add_argument("path", help="Path to Python executable")
    add_parser.set_defaults(func=cmd_config_add)
    
    # config remove
    remove_parser = config_subparsers.add_parser("remove", help="Remove Python interpreter")
    remove_parser.add_argument("name", help="Name of interpreter to remove")
    remove_parser.set_defaults(func=cmd_config_remove)
    
    # config list
    list_parser = config_subparsers.add_parser("list", help="List Python interpreters")
    list_parser.set_defaults(func=cmd_config_list)
    
    # config default
    default_parser = config_subparsers.add_parser("default", help="Set default interpreter")
    default_parser.add_argument("name", help="Name of interpreter to set as default")
    default_parser.set_defaults(func=cmd_config_default)
    
    # which command
    which_parser = subparsers.add_parser("which", help="Show which Python will be used")
    which_parser.set_defaults(func=cmd_which)
    
    # status command
    status_parser = subparsers.add_parser("status", help="Show pyshim status")
    status_parser.set_defaults(func=cmd_status)
    
    args = parser.parse_args()
    
    if not args.command:
        parser.print_help()
        return 0
    
    if hasattr(args, "func"):
        return args.func(args)
    else:
        if args.command == "config":
            config_parser.print_help()
        return 0


if __name__ == "__main__":
    sys.exit(main())
