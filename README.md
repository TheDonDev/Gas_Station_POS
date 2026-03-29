# Gas Store POS

A Flutter-based Point of Sale (POS) application designed for Gas Stores to manage inventory, sales, and receipt printing.

## Features

- **Inventory Management**:
  - Track full and empty cylinder stock.
  - Manage distinct prices for Refills vs New cylinders.
  - Add, Edit, and Delete products.
- **Point of Sale**:
  - Cart system for processing multiple items.
  - Automatic total calculation.
- **Receipt Printing**:
  - Supports Thermal Printers (ESC/POS).
  - Connectivity via USB and Bluetooth.
- **Reports**:
  - Sales dashboard with visual charts.
  - History of daily sales performance.

## Getting Started

### Prerequisites

- Flutter SDK installed.
- Visual Studio (C++ workload) for Windows development.

### Installation

1.  Clone the repository.
2.  Install dependencies:
    ```bash
    flutter pub get
    ```
3.  Run the application:
    ```bash
    flutter run -d windows
    ```

### Build Output

After building, the executable file (`gas_store_pos.exe`) can be found in:
`build/windows/x64/runner/Release/`

## Deployment

To package the application for distribution (e.g., using Inno Setup):

1.  Build the release version:
    ```bash
    flutter build windows
    ```
2.  Ensure you bundle **all** files from:
    `build\windows\x64\runner\Release\`

    This includes:
    - `gas_store_pos.exe`
    - `flutter_windows.dll`
    - `data\` folder
    - `sqlite3.dll`

> **Note:** This application is 64-bit (x64) only. It will not run on 32-bit Windows installations.

## Technologies

- **Flutter**: UI Framework.
- **Provider**: State Management.
- **SQLite**: Local Database.
- **esc_pos_utils**: Receipt formatting.