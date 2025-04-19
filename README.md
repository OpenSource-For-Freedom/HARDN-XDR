
![GitHub release (latest by date)](https://img.shields.io/github/v/release/OpenSource-For-Freedom/HARDN?include_prereleases)


<p align="center">
  <img src="docs/assets/HARDN(1).png" alt="HARDN Logo" width="300px" /><br><br>
  <img src="https://img.shields.io/badge/The_Linux_Security_Project-red?style=for-the-badge&labelColor=black" alt="The Linux Security Project"><br><br>
  <code>HARDN-Endpoint</code>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/OVERVIEW-white?style=for-the-badge&labelColor=black" alt="OVERVIEW"><br><br>
</p>
HARDN Endpoint is a robust and secure endpoint management solution designed to simplify and enhance the management of devices in your network. It provides advanced features for monitoring, securing, and maintaining endpoints efficiently.

<p align="center">
  <img src="https://img.shields.io/badge/FEATURES-white?style=for-the-badge&labelColor=black" alt="FEATURES"><br><br>
</p>

- **Comprehensive Monitoring**: Real-time insights into endpoint performance and activity.
- **Enhanced Security**: Protect endpoints with advanced security protocols.
- **Scalability**: Manage endpoints across small to large-scale networks.
- **User-Friendly Interface**: Intuitive design for seamless navigation and management.

<p align="center">
  <img src="https://img.shields.io/badge/PURPOSE-white?style=for-the-badge&labelColor=black" alt="PURPOSE"><br><br>
</p>

The purpose of HARDN Endpoint is to empower IT administrators and users with the tools they need to ensure endpoint security, optimize performance, and maintain compliance across their organization.

<p align="center">
  <img src="https://img.shields.io/badge/INSTALLATION-white?style=for-the-badge&labelColor=black" alt="INSTALLATION"><br><br>
</p>


Coming Soon..


<p align="center">
  <img src="https://img.shields.io/badge/CONTRIBUTION-white?style=for-the-badge&labelColor=black" alt="CONTRIBUTION"><br><br>
We welcome contributions! 

</p>

<p align="center">
  <img src="https://img.shields.io/badge/PROJECT PARTNERS-white?style=for-the-badge&labelColor=black" alt="PROJECT PARTNERS"><br><br>
</p>


<p align="center">
  <img src="docs/assets/cybersynapse.png" alt="cybersynapse Logo" />
</p>



<p align="center">
  <img src="https://img.shields.io/badge/LICENSE-white?style=for-the-badge&labelColor=black" alt="LICENSE"><br><br>
This project is licensed under the GPLicense
  
</p>


<p align="center">
  <img src="https://img.shields.io/badge/CONTACT-white?style=for-the-badge&labelColor=black" alt="CONTACT"><br><br>
office@cybersynapse.ro
</p>


<p align="center">
=====FILE STRUCTURE=====

```
HARDN/
├── .github/                # workflows
│   └── workflows/
│       ├── deb-build.yml
│       ├── python_test.yml
│       |-- shell_test.yml
|       |__ hardn.yml       # testing workflow for orchestration
├── debian/                 # packaging files
│   ├── changelog
│   ├── compat
│   ├── control
│   ├── rules
│   ├── hardn.install
│   └── ...
├── src/                    # Source code
│   ├── gui/                # GUI-related files
│   │   ├── __init__.py
│   │   ├── app.py
│   │   ├── main_window.py
│   │   ├── docs/           # Documentation 
│   │   ├── controllers/
│   │   ├── models/
│   │   ├── resources/
│   │   ├── utils/
│   │   └── views/
│   ├── setup/              # Setup s
│   │   ├── __init__.py
│   │   ├── setup.sh
│   │   └── packages.sh
│   ├── kernel.rs           # Kernel hardening 
│   ├── hardn.py            # Main entry point
│   └── ...
├── tests/                  # file and unit integration tests
│   ├── test_hardn.py
│   ├── test_kernel.rs
│   ├── test_main.c
│   └── ...
├── build/                  # build artifacts (ignored in `.gitignore`)
├── dist/                   # Distribution packages (ignored in `.gitignore`)
├── README.md               # Project documentation
├── Makefile                # Build automation
├── requirements.txt        # Python dependencies
├── pyproject.toml          # Python project metadata
└── environment.yml         # Conda environment file (if applicable)
```
</p>