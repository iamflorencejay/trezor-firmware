# Automatically generated by pb2py
# fmt: off
# isort:skip_file
import protobuf as p

if __debug__:
    try:
        from typing import Dict, List, Optional  # noqa: F401
        from typing_extensions import Literal  # noqa: F401
    except ImportError:
        pass


class PassphraseAck(p.MessageType):
    MESSAGE_WIRE_TYPE = 42

    def __init__(
        self,
        *,
        passphrase: Optional[str] = None,
        on_device: Optional[bool] = None,
    ) -> None:
        self.passphrase = passphrase
        self.on_device = on_device

    @classmethod
    def get_fields(cls) -> Dict:
        return {
            1: ('passphrase', p.UnicodeType, None),
            3: ('on_device', p.BoolType, None),
        }