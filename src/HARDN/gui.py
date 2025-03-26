# placeholder for GUI setup code
# This file is intended to contain the setup code for the graphical user interface (GUI)
# of the application. It may include the initialization of GUI components,
# event handlers, and any other necessary setup procedures.
# The actual implementation will depend on the specific GUI framework being used,


# for @Intel420x

import tkinter as tk

# build gui tkinter code to print the hardn banner
def display_banner():
    def print_ascii_art():
        art = """
             ██░ ██  ▄▄▄       ██▀███  ▓█████▄  ███▄    █ 
            ▓██░ ██▒▒████▄    ▓██ ▒ ██▒▒██▀ ██▌ ██ ▀█   █ 
            ▒██▀▀██░▒██  ▀█▄  ▓██ ░▄█ ▒░██   █▌▓██  ▀█ ██▒
            ░▓█ ░██ ░██▄▄▄▄██ ▒██▀▀█▄  ░▓█▄   ▌▓██▒  ▐▌██▒
            ░▓█▒░██▓ ▓█   ▓██▒░██▓ ▒██▒░▒████▓ ▒██░   ▓██░
             ▒ ░░▒░▒ ▒▒   ▓▒█░░ ▒▓ ░▒▓░ ▒▒▓  ▒ ░ ▒░   ▒ ▒ 
             ▒ ░▒░ ░  ▒   ▒▒ ░  ░▒ ░ ▒░ ░ ▒  ▒ ░ ░░   ░ ▒░
             ░  ░░ ░  ░   ▒     ░░   ░  ░ ░  ░    ░   ░ ░ 
             ░  ░  ░      ░  ░   ░        ░             ░ 
                                ░                 
                "HARDN" - The Linux Security Project
              ----------------------------------------
              "A single Debian tool to fully secure an 
             OS using automation, monitoring, heuristics 
                        and availability.
                     
                          License: MIT
              ----------------------------------------
        """
        return art

    banner_text = print_ascii_art()
    root = tk.Tk()
    root.title("HARDN Banner")

    root.geometry("600x400")
    root.resizable(True, True)
    root.configure(bg="black")  
    
    text_widget = tk.Text(root, wrap="word", font=("Courier", 10))
    text_widget.insert("1.0", banner_text)
    text_widget.configure(state="disabled")
    text_widget.pack(pady=20, padx=20)
    
    root.mainloop()

# Call the function to display the banner
display_banner()
