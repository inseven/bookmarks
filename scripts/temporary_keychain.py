#!/usr/bin/env python3

import argparse
import functools
import json
import logging
import os
import secrets
import subprocess
import sys


COMMANDS = {}

class Command(object):

    def __init__(self, name, help, arguments, callback):
        self.name = name
        self.help = help
        self.arguments = arguments
        self.callback = callback

class Argument(object):

    def __init__(self, *args, **kwargs):
        self.args = args
        self.kwargs = kwargs


def command(name, help="", arguments=[]):
    def wrapper(fn):
        @functools.wraps(fn)
        def inner(*args, **kwargs):
            return fn(*args, **kwargs)
        COMMANDS[name] = Command(name, help, arguments, inner)
        return inner
    return wrapper


class CommandParser(object):

    def __init__(self, *args, **kwargs):
        self.parser = argparse.ArgumentParser(*args, **kwargs)
        subparsers = self.parser.add_subparsers(help="command")
        for name, command in COMMANDS.items():
            subparser = subparsers.add_parser(command.name, help=command.help)
            for argument in command.arguments:
                subparser.add_argument(*(argument.args), **(argument.kwargs))
            subparser.set_defaults(fn=command.callback)

    def run(self):
        options = self.parser.parse_args()
        if 'fn' not in options:
            logging.error("No command specified.")
            exit(1)
        options.fn(options)


def list_keychains():
    keychains = subprocess.check_output(["security", "list-keychains", "-d", "user"]).decode("utf-8").strip().split("\n")
    keychains = [json.loads(keychain) for keychain in keychains]  # list-keychains quotes the strings
    return keychains


def create_keychain(path, password):
    subprocess.check_call(["security", "create-keychain", "-p", "12345678", path])
    subprocess.check_call(["security", "set-keychain-settings", "-lut", "21600", path])


def unlock_keychain(path, password):
    subprocess.check_call(["security", "unlock-keychain", "-p", password, path])


def add_keychain(path):
    subprocess.check_call(["security", "list-keychains", "-d", "user", "-s"] + list_keychains() + [path])


@command("create-keychain", help="Safely create a temporary keychain", arguments=[
    Argument("path", help="path at which to create the keychain"),
    Argument("--password", "-p", action="store_true", default=False, help="read password from stdin")
])
def command_create_keychain(options):
    path = os.path.abspath(options.path)
    logging.info("Creating keychain '%s'...", path)
    password = secrets.token_hex()
    if options.password:
        password = sys.stdin.read().strip()
    create_keychain(path, password)
    add_keychain(path)
    unlock_keychain(path, password)


@command("delete-keychain", help="Safely delete a temporary keychain removing it from the active set", arguments=[
    Argument("path", help="path of the keychain to delete")
])
def command_delete_keychain(options):
    path = os.path.abspath(options.path)
    logging.info("Deleting keychain '%s'...", path)
    subprocess.check_call(["security", "delete-keychain", path])


def main():
    parser = CommandParser(description="Create and register a temporary keychain for development")
    parser.run()


if __name__ == "__main__":
    main()