
print("##############################################################")
print("#       ██░ ██  ▄▄▄       ██▀███  ▓█████▄  ███▄    █         #")
print("#      ▓██░ ██▒▒████▄    ▓██ ▒ ██▒▒██▀ ██▌ ██ ▀█   █         #")
print("#      ▒██▀▀██░▒██  ▀█▄  ▓██ ░▄█ ▒░██   █▌▓██  ▀█ ██▒        #")
print("#      ░▓█ ░██ ░██▄▄▄▄██ ▒██▀▀█▄  ░▓█▄   ▌▓██▒  ▐▌██▒        #")
print("#      ░▓█▒░██▓ ▓█   ▓██▒░██▓ ▒██▒░▒████▓ ▒██░   ▓██░        #")
print("#       ▒ ░░▒░▒ ▒▒   ▓▒█░░ ▒▓ ░▒▓░ ▒▒▓  ▒ ░ ▒░   ▒ ▒         #")
print("#       ▒ ░▒░ ░  ▒   ▒▒ ░  ░▒ ░ ▒░ ░ ▒  ▒ ░ ░░   ░ ▒░        #")
print("#       ░  ░░ ░  ░   ▒     ░░   ░  ░ ░  ░    ░   ░ ░         #")
print("#       ░  ░  ░      ░  ░   ░        ░             ░         #")
print("#                           ░                                #")
print("#               THE LINUX SECURITY PROJECT                   #")
print("##############################################################")



import tkinter as tk
from tkinter import messagebox
import hardn 

class HARDNGUI:
  def __init__(self, root):
    self.root = root
    self.root.title("HARDN")
    self.root.geometry("400x300")
    self.root.configure(bg="black")  # Set background color to black


    self.label = tk.Label(root, text="HARDN", font=("Arial", 24), bg="black", fg="grey")
    self.label.pack(pady=20)

    self.action_button = tk.Button(root, text="Perform Action", command=self.perform_action, bg="white", fg="black")
    self.action_button.pack(pady=10)

   
    self.exit_button = tk.Button(root, text="Exit", command=root.quit, bg="white", fg="black")
    self.exit_button.pack(pady=10)

  def perform_action(self):
    try:
      result = hardn.perform_action()  
      messagebox.showinfo("Action", f"Action performed: {result}")
    except AttributeError:
      messagebox.showerror("Error", "Function 'perform_action' not found in hardn.py")
    except Exception as e:
      messagebox.showerror("Error", f"An error occurred: {e}")

if __name__ == "__main__":
  root = tk.Tk()
  app = HARDNGUI(root)
  root.mainloop()
