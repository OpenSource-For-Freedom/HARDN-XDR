# filepath: /home/tim/Desktop/HARDN/setup/setup.py
from setuptools import setup, find_packages

setup(
    name="HARDN",
    version="1.0.0",
    packages=find_packages(),
    install_requires=[
        "pexpect",
        "PyYAML==3.13",
        "cython",
    ],
    entry_points={
        "console_scripts": [
            "hardn=src.hardn:main",
        ],
    },
)