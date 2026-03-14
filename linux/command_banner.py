"""Command reference banner -- shown on exit of all CLI tools.

Port of Windows MatrixShader.Cli.ConsoleHelper.ShowCommandBanner().
Displays the 5 main commands with Matrix green names and dim descriptions.
"""

# ANSI escape codes
GREEN = '\033[38;2;53;179;129m'   # #35B381
DIM = '\033[2m'
RESET = '\033[0m'


def show_command_banner():
    """Print the command reference banner to stdout."""
    print()
    print(f" {DIM}COMMANDS{RESET}")
    print(f"  {GREEN}wakeupneo{RESET}          {DIM}Start here{RESET}")
    print(f"  {GREEN}construct{RESET}          {DIM}Launch individual Matrix terminal (--help for colors){RESET}")
    print(f"  {GREEN}bluepill{RESET}           {DIM}Quickly relaunch last saved settings{RESET}")
    print(f"  {GREEN}redpill{RESET}            {DIM}Full control panel (fine tuning){RESET}")
    print(f"  {GREEN}matrixlite{RESET}         {DIM}Visual effect only{RESET}")


if __name__ == "__main__":
    show_command_banner()
