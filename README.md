# Earthy

An e-commerce application for local producers and consumers, developed for my thesis project.

## Setting up:
* Please make sure that you have virtualization enabled in your BIOS.

First, download and install Android studio from its website
(https://developer.android.com/studio). 
The version used was Android Studio Iguana. During installation choose Standard installation, accept the terms and follow the installer.
If you get any errors during the installation about failing to install HAXM, we will fix it later.

Open Android studio and navigate to the plugins screen. 
Search for Flutter, install and restart the IDE.

Then we have to install the dart sdk from https://dart.dev/get-dart.
To do this, for windows it is required to install Chocolatery (https://chocolatey.org/install). 
This can be done by opening powershell with admin rights and then running the following command:
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

* If the command was run without admin rights you will need to delete the C:\ProgramData\chocolatey folder and repeat by opening PowerShell with admin rights 

Close PowerShell and reopen with admin rights again. Following, go to the "C:\" path using the "cd" command.
Then, run "choco install dart-sdk" and follow the process (click yes when asked to run a script).

In Android Studio, open the project folder (earthy) and navigate to File -> Settings-> Languages & frameworks -> Dart and tick Enable Dart support for project "earthy".
Then for dart sdk path click on the three dots and find the dart sdk (it should be located in "C:\tools\dart-sdk".
Also, tick on the Project "earthy" in the box below. Then, click apply and ok.

Now we need to install the flutter sdk, Visit "https://docs.flutter.dev/get-started/install/windows/mobile?tab=download",
click android and then under "Install the Flutter SDK" click "Download and install" and download the installer.
After it is downloaded, extract the folder in your "C:\Users\{username}" path under a new folder you will call "dev".
Now we need to update the Windows PATH variable. 
Open the control panel and search for "environment variables" and click on the "Edit the system environment variables".

Then click on "environment variables" under the Advanced tab. Now, as described in the installation instructions of flutter:
In the User variables for (username) section, look for the Path entry.

If the entry exists, double-click on it.
The Edit Environment Variable dialog displays.

Double-click in an empty row.
Type %USERPROFILE%\dev\flutter\bin.
Click the %USERPROFILE%\dev\flutter\bin entry.
Click Move Up until the Flutter entry sits at the top of the list.
Click OK three times.

If the entry doesn’t exist, click New….
The Edit Environment Variable dialog displays.
In the Variable Name box, type Path.
In the Variable Value box, type %USERPROFILE%\dev\flutter\bin
Click OK three times.

You can confirm that everything works by opening a new command prompt and running "flutter doctor".
Now close and reopen Android Studio.

Open a terminal in Android Studio (bottom left of the window) and run the command "flutter pub get" twice.

Now close and reopen Android Studio again.

Following, click on the device manager icon on the right of the window. Click on the play button to start the simulator.

* In case a simulator is not present in the screen, you will need to add one by clicking the "+" button inside 
the device manager window. Then, you can pick Pixel 8 under Phones, click next and from the System Image screen, 
click the download button next to VanillaIceCream in the list, follow the process and then click next & finish. 
Finally, click the play button.

You will be prompted to Install HAXM if it is not installed. Click on "ok" and follow the instructions.
If you encounter any issues while installing it:
Visit "https://github.com/intel/haxm/releases" , download the installer and install it manually.
Perform the installation.
Make sure that in the windows features (you can search windows features in windows search), Windows Hypervision Platform and 
Virtual Machine platform are ticked and then click ok. 
If they are not, you will be prompted to install them.
Then try closing and reopening Android Studio and start the simulator again .

Now, the play icon at the top middle of the window should be green and you will be able to click on it for main.dart. 
Click on it and the application should start on the simulator. It might take some time the first time. 

## Sample Accounts for consumers:
e-mails: 
    test1@hotmail.com
    test2@hotmail.com
    test3@hotmail.com

For all of them the default password is "test1234".

## Sample Accounts for producers:
e-mails:
    producer1@hotmail.com
    producer2@hotmail.com
    producer3@hotmail.com
    producer4@hotmail.com

For all of them the default password is "test1234".

* You can always create new accounts for both consumer and producers using the application.

## GitHub repository link
https://github.com/comChrisT/earthy

## If you encounter any issues feel free to contact be on ctopaka@uclan.ac.uk or any other form of communication.

