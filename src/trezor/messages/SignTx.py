# Automatically generated by pb2py
import protobuf as p


class SignTx(p.MessageType):
    MESSAGE_WIRE_TYPE = 15
    FIELDS = {
        1: ('outputs_count', p.UVarintType, 0),  # required
        2: ('inputs_count', p.UVarintType, 0),  # required
        3: ('coin_name', p.UnicodeType, 0),  # default='Bitcoin'
        4: ('version', p.UVarintType, 0),  # default=1
        5: ('lock_time', p.UVarintType, 0),  # default=0
        6: ('decred_expiry', p.UVarintType, 0),
        7: ('overwintered', p.BoolType, 0),
    }

    def __init__(
        self,
        outputs_count: int = None,
        inputs_count: int = None,
        coin_name: str = None,
        version: int = None,
        lock_time: int = None,
        decred_expiry: int = None,
        overwintered: bool = None
    ) -> None:
        self.outputs_count = outputs_count
        self.inputs_count = inputs_count
        self.coin_name = coin_name
        self.version = version
        self.lock_time = lock_time
        self.decred_expiry = decred_expiry
        self.overwintered = overwintered
