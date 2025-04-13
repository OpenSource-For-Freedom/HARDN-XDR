import subprocess


# this is a module for executing shell commands
# it is to be imported to other scripts

def exec_command(command, args, status_callback=None):
    try:
        if status_callback:
            status_callback(f"Executing: {command} {' '.join(args)}")
        print(f"Executing: {command} {' '.join(args)}")
        process = subprocess.run([command] + args, check=True, text=True, stdout=subprocess.PIPE,
                                 stderr=subprocess.PIPE, timeout=300)
        if status_callback:
            status_callback(f"Completed: {command} {' '.join(args)}")
        print(process.stdout)
        return process.stdout
    except subprocess.CalledProcessError as e:
        if status_callback:
            status_callback(f"Error executing '{command} {' '.join(args)}': {e.stderr}")
        print(f"Error executing command '{command} {' '.join(args)}': {e.stderr}")
    except subprocess.TimeoutExpired:
        if status_callback:
            status_callback(f"Command timed out: {command} {' '.join(args)}")
        print(f"Command timed out: {command} {' '.join(args)}")
    except Exception as e:
        if status_callback:
            status_callback(f"Unexpected error: {str(e)}")
        print(f"Unexpected error: {str(e)}")
    return None

