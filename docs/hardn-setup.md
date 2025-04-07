# HARD Setup Guide

Welcome to the HARD setup guide! Follow these steps to install and configure the `.deb` package quickly and efficiently.

---

## Prerequisites

Before you begin, ensure you have the following:
- A compatible operating system (Debian 12 based Linux distribution).
- Administrative privileges on your system.

---

## Step 1: Download the `.deb` Package

Download the latest `.deb` package from the [releases page](https://github.com/opensource-for-freedom/HARDN/releases).

---

## Step 2: Install the `.deb` Package

Use the following command to install the package:

```bash
sudo dpkg -i HARDN_1.1.0.deb
```

If there are missing dependencies, fix them with:

```bash
sudo apt-get install -f
```

---

## Step 3: Start the Service

Start the HARDN service using:

```bash
sudo systemctl start hardn
```

Enable the service to start on boot:

```bash
sudo syst# HARD Setup Guide

Welcome to the HARD setup guide! Follow these steps to install and configure the `.deb` package quickly and efficiently.

---

## Prerequisites

Before you begin, ensure you have the following:
- A compatible operating system (Debian 12 based Linux distribution).
- Administrative privileges on your system.

---

## Step 1: Download the `.deb` Package

Download the latest `.deb` package from the [releases page](https://github.com/opensource-for-freedom/HARDN/releases).

---

## Step 2: Install the `.deb` Package

Use the following command to install the package:

```bash
sudo dpkg -i HARDN_1.1.0.deb
```

If there are missing dependencies, fix them with:

```bash
sudo apt-get install -f
```

---

## Step 3: Start the Service

Start the HARDN service using:

```bash
sudo systemctl start hardn
```

Enable the service to start on boot:

```bash
sudo systemctl enable hardn
```

## Step 4: Run Tests (Optional)

To ensure everything is working correctly, run the test suite:

```bash
sudo hardn-cli test
```

---

## Troubleshooting

- **Dependency Issues**: Ensure all dependencies are resolved using `sudo apt-get install -f`.
- **Environment Variables**: Verify the `/etc/hardn/config.env` file for accuracy.
- **Service Issues**: Check the service status with `sudo systemctl status hardn`.

---

## Conclusion

You have successfully installed and configured the HARDN application. For further assistance, refer to the [documentation](https://github.com/opensource-for-freedom/HARDN/wiki) or contact support.

emctl enable hardn
```

## Step 4: Run Tests (Optional)

To ensure everything is working correctly, run the test suite:

```bash
sudo hardn-cli test
```

---

## Troubleshooting

- **Dependency Issues**: Ensure all dependencies are resolved using `sudo apt-get install -f`.
- **Environment Variables**: Verify the `/etc/hardn/config.env` file for accuracy.
- **Service Issues**: Check the service status with `sudo systemctl status hardn`.

---

## Conclusion

You have successfully installed and configured the HARDN application. For further assistance, refer to the [documentation](https://github.com/opensource-for-freedom/HARDN/wiki) or contact support.

