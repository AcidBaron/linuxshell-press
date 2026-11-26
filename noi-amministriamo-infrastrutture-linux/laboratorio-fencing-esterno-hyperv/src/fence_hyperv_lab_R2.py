#!/usr/bin/python3
"""Experimental Hyper-V fence agent for an isolated lab (R1).

Uses the system fence-agents 'fencing' library. Only web01 is permitted.
No production suitability or automatic cluster deployment is implied.
"""

import subprocess
import sys

sys.path.append('/usr/share/fence')
import fencing as f

ALLOWED_VMS = {'linux-client01', 'dhcp-client01'}


def vm_name(options):
    name = options.get('--plug', '')
    if name not in ALLOWED_VMS:
        raise ValueError('VM not authorized for lab fencing: ' + repr(name))
    return name


def powershell(options, expression):
    # Only fixed expressions are called; VM name is from an explicit allowlist.
    script = (
        "$ErrorActionPreference='Stop'; "
        "try { " + expression + " } "
        "catch { [Console]::Error.WriteLine($_.ToString()); exit 1 }"
    )
    command = [
        '/usr/bin/ssh', '-T',
        '-i', options['--identity-file'],
        '-o', 'IdentitiesOnly=yes',
        '-o', 'BatchMode=yes',
        '-o', 'StrictHostKeyChecking=yes',
        '-o', 'ConnectTimeout=5',
        options['--username'] + '@' + options['--ip'],
        'powershell.exe -NoProfile -NonInteractive -Command ' + '"' + script.replace('"', '`"') + '"',
    ]
    result = subprocess.run(command, capture_output=True, text=True, timeout=20, check=False)
    if result.returncode != 0:
        raise RuntimeError('Hyper-V/SSH command failed: ' + (result.stderr.strip() or str(result.returncode)))
    return result.stdout.strip()


def get_power_status(connection, options):
    name = vm_name(options)
    result = powershell(options, "[Console]::WriteLine((Get-VM -Name '" + name + "').State.ToString())")
    if result == 'Running':
        return 'on'
    if result == 'Off':
        return 'off'
    raise RuntimeError('Unknown or unsafe VM state: ' + repr(result))


def set_power_status(connection, options):
    name = vm_name(options)
    action = options['--action']
    if action == 'off':
        expression = "Stop-VM -Name '" + name + "' -TurnOff -Confirm:$false -ErrorAction Stop"
    elif action == 'on':
        expression = "Start-VM -Name '" + name + "' -ErrorAction Stop"
    else:
        raise ValueError('Unsupported power action: ' + action)
    powershell(options, expression)
    # The common fence_action() code subsequently verifies the power state.


def get_outlets_status(connection, options):
    return {
        name: ('Hyper-V cluster node', get_power_status(
            connection, {**options, '--plug': name}))
        for name in sorted(ALLOWED_VMS)
    }


def main():
    device_opt = ['ipaddr', 'login', 'secure', 'port', 'no_password']
    options = f.check_input(device_opt, f.process_input(device_opt))
    docs = {
        'shortdesc': 'Experimental Hyper-V lab fence agent',
        'longdesc': 'Uses SSH and Windows PowerShell to control the two allowlisted Hyper-V cluster nodes. Not for production.',
        'vendorurl': 'https://github.com/',
    }
    f.show_docs(options, docs)
    try:
        # The stock library handles metadata, actions, status checks and exit codes.
        result = f.fence_action(None, options, set_power_status, get_power_status, get_outlets_status)
    except (OSError, ValueError, RuntimeError, subprocess.TimeoutExpired) as exc:
        print('Fence lab error: ' + str(exc), file=sys.stderr)
        return 1
    return 0 if result is None else result


if __name__ == '__main__':
    sys.exit(main())
