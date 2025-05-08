ABC
Arc Bitwig Controller

This device controls Bitwig parameters with a monome arc. It has been achieved by using PlugData to generate and receive OSC received/sent from BitWig using DrivenByMoss and the OSC controller script.

The necessary tools for this are as follows:

A monome arc

PlugData

https://plugdata.org/



DrivenByMoss controller extension

https://www.mossgrabers.de/Software/Bitwig/Bitwig.html


Once you have installed both PlugData and DrivenByMoss, place the ABC script in the PlugData patches folder, which is often created during software installation, in your Documents folder.

Open Bitwig, go to the controller section of the settings panel, and create a new controller. While General is selected, click on the dropdown menu to your left and select OpenSoundController or OSC.

Set up your OSC settings as follows:

![alt text](https://github.com/kasselvania/bitwig-arc/blob/main/OSC-Setup.png "BitWig OSC Settings")

Next, add an instrument track, and select PlugData. PlugData's main menu will open. Open the arc-bitwig-controller.pd script found in the folder. Once it loads up, you can connect your arc. If LEDs are not lit, try moving an encoder. The default LEDs should come on.

There are two modes, Device and Project. This indicates which "device controls" are being grabbed by the controller. The standard boot mode shows Device mode. This is indicated by a single LED being lit at 6 o'clock. When you press the Mode button in the device parameters or the PlugData window, you will switch to Project mode, which will be indicated by two LEDs lit.
