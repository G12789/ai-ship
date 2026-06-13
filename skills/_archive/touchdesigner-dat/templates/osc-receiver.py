# TouchDesigner Python DAT — OSC receiver template
# Paste into Text DAT, connect to CHOP Execute or Timer

class OSCReceiver:
    def __init__(self, ownerComp):
        self.ownerComp = ownerComp

    def onReceiveOSC(self, message, address, args, peer):
        debug(message, address)
        # args[0].val — map to custom params
        return
