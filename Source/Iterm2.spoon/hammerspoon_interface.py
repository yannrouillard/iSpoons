#!/usr/bin/env python3

import json
from pathlib import Path
from typing import Optional

import iterm2
from iterm2 import Window


def iter_all_tabs_with_session(app):
    for window in app.windows:
        for tab in window.tabs:
            if tab.current_session is not None:
                yield tab


async def get_or_create_tab_in_folder(
    app, tab_folder: str, command: Optional[str] = None
) -> iterm2.Tab:
    for tab in iter_all_tabs_with_session(app):
        current_folder = await tab.current_session.async_get_variable("path")
        if Path(current_folder) == Path(tab_folder):
            return tab

    current_window = app.current_window or Window.async_create(app.connection)
    profile = iterm2.LocalWriteOnlyProfile()
    profile.set_initial_directory_mode(
        iterm2.InitialWorkingDirectory.INITIAL_WORKING_DIRECTORY_CUSTOM
    )
    profile.set_custom_directory(tab_folder)
    tab = await current_window.async_create_tab(profile_customizations=profile)
    if command:
        await tab.current_session.async_send_text(command + "\n")
    return tab


async def main(connection):
    app = await iterm2.async_get_app(connection)

    @iterm2.RPC
    async def get_active_tab() -> Optional[iterm2.Tab]:
        current_window = app.current_window
        if not current_window or not current_window.current_tab:
            return None

        current_tab = current_window.current_tab
        working_directory = await current_tab.current_session.async_get_variable("path")
        title = await current_tab.current_session.async_get_variable("autoName")
        return json.dumps(
            {
                "title": title,
                "working_directory": str(Path(working_directory).resolve()),
                "id": current_tab.tab_id,
            }
        )

    await get_active_tab.async_register(connection)

    @iterm2.RPC
    async def open_or_activate_tab(working_directory: Optional[str]):
        if working_directory is None:
            return

        tab = await get_or_create_tab_in_folder(app, working_directory)
        await tab.async_activate()
        await app.async_activate()

    await open_or_activate_tab.async_register(connection)

    @iterm2.RPC
    async def create_or_activate_git_tab(
        git_folders_root: Optional[str], git_repository_url: Optional[str]
    ):
        if git_folders_root is None or git_repository_url is None:
            return

        ssh_git_repository_url = git_repository_url.replace(
            "https://github.com/", "git@github.com:"
        )
        git_repository_name = Path(git_repository_url).stem
        git_repository_folder = Path(git_folders_root) / git_repository_name

        if git_repository_folder.exists():
            tab = await get_or_create_tab_in_folder(app, str(git_repository_folder))
        else:
            checkout_command = (
                f'git clone "{ssh_git_repository_url}" && cd "{git_repository_name}"'
            )
            tab = await get_or_create_tab_in_folder(
                app, git_folders_root, command=checkout_command
            )
        await tab.async_activate()
        await app.async_activate()

    await create_or_activate_git_tab.async_register(connection)

    @iterm2.RPC
    async def close_matching_tabs(working_directory_prefix: Optional[str]):
        if working_directory_prefix is None:
            return

        for tab in iter_all_tabs_with_session(app):
            current_folder = await tab.current_session.async_get_variable("path")
            if Path(current_folder).is_relative_to(working_directory_prefix):
                await tab.async_close()

    await close_matching_tabs.async_register(connection)


iterm2.run_forever(main)
