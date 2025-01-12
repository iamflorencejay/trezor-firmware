# This file is part of the Trezor project.
#
# Copyright (C) 2012-2019 SatoshiLabs and contributors
#
# This library is free software: you can redistribute it and/or modify
# it under the terms of the GNU Lesser General Public License version 3
# as published by the Free Software Foundation.
#
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Lesser General Public License for more details.
#
# You should have received a copy of the License along with this library.
# If not, see <https://www.gnu.org/licenses/lgpl-3.0.html>.

import pytest

from trezorlib import btc, messages as proto
from trezorlib.exceptions import TrezorFailure
from trezorlib.tools import parse_path

VECTORS = (  # coin, path, script_type, address
    (
        "Testnet",
        "84'/1'/0'/0/0",
        proto.InputScriptType.SPENDWITNESS,
        "tb1qkvwu9g3k2pdxewfqr7syz89r3gj557l3uuf9r9",
    ),
    (
        "Testnet",
        "84'/1'/0'/1/0",
        proto.InputScriptType.SPENDWITNESS,
        "tb1qejqxwzfld7zr6mf7ygqy5s5se5xq7vmt96jk9x",
    ),
    (
        "Bitcoin",
        "84'/0'/0'/0/0",
        proto.InputScriptType.SPENDWITNESS,
        "bc1qannfxke2tfd4l7vhepehpvt05y83v3qsf6nfkk",
    ),
    (
        "Bitcoin",
        "84'/0'/0'/1/0",
        proto.InputScriptType.SPENDWITNESS,
        "bc1qktmhrsmsenepnnfst8x6j27l0uqv7ggrg8x38q",
    ),
    pytest.param(
        "Groestlcoin",
        "84'/17'/0'/0/0",
        proto.InputScriptType.SPENDWITNESS,
        "grs1qw4teyraux2s77nhjdwh9ar8rl9dt7zww8r6lne",
        marks=pytest.mark.altcoin,
    ),
    pytest.param(
        "Elements",
        "84'/1'/0'/0/0",
        proto.InputScriptType.SPENDWITNESS,
        "ert1qkvwu9g3k2pdxewfqr7syz89r3gj557l3xp9k2v",
        marks=pytest.mark.altcoin,
    ),
)


@pytest.mark.parametrize("show_display", (True, False))
@pytest.mark.parametrize("coin, path, script_type, address", VECTORS)
def test_show_segwit(client, show_display, coin, path, script_type, address):
    assert (
        btc.get_address(
            client,
            coin,
            parse_path(path),
            show_display,
            None,
            script_type=script_type,
        )
        == address
    )


@pytest.mark.multisig
def test_show_multisig_3(client):
    nodes = [
        btc.get_public_node(
            client, parse_path(f"84'/1'/{index}'"), coin_name="Testnet"
        ).node
        for index in range(1, 4)
    ]
    multisig1 = proto.MultisigRedeemScriptType(
        nodes=nodes, address_n=[0, 0], signatures=[b"", b"", b""], m=2
    )
    multisig2 = proto.MultisigRedeemScriptType(
        nodes=nodes, address_n=[0, 1], signatures=[b"", b"", b""], m=2
    )
    for i in [1, 2, 3]:
        assert (
            btc.get_address(
                client,
                "Testnet",
                parse_path(f"84'/1'/{i}'/0/1"),
                False,
                multisig2,
                script_type=proto.InputScriptType.SPENDWITNESS,
            )
            == "tb1qauuv4e2pwjkr4ws5f8p20hu562jlqpe5h74whxqrwf7pufsgzcms9y8set"
        )
        assert (
            btc.get_address(
                client,
                "Testnet",
                parse_path(f"84'/1'/{i}'/0/0"),
                False,
                multisig1,
                script_type=proto.InputScriptType.SPENDWITNESS,
            )
            == "tb1qgvn67p4twmpqhs8c39tukmu9geamtf7x0z3flwf9rrw4ff3h6d2qt0czq3"
        )


@pytest.mark.multisig
@pytest.mark.parametrize("show_display", (True, False))
def test_multisig_missing(client, show_display):
    # Multisig with global suffix specification.
    # Use account numbers 1, 2 and 3 to create a valid multisig,
    # but not containing the keys from account 0 used below.
    nodes = [
        btc.get_public_node(client, parse_path(f"84'/0'/{i}'")).node
        for i in range(1, 4)
    ]
    multisig1 = proto.MultisigRedeemScriptType(
        nodes=nodes, address_n=[0, 0], signatures=[b"", b"", b""], m=2
    )

    # Multisig with per-node suffix specification.
    node = btc.get_public_node(
        client, parse_path("84h/0h/0h/0"), coin_name="Bitcoin"
    ).node
    multisig2 = proto.MultisigRedeemScriptType(
        pubkeys=[
            proto.HDNodePathType(node=node, address_n=[1]),
            proto.HDNodePathType(node=node, address_n=[2]),
            proto.HDNodePathType(node=node, address_n=[3]),
        ],
        signatures=[b"", b"", b""],
        m=2,
    )

    for multisig in (multisig1, multisig2):
        with pytest.raises(TrezorFailure):
            btc.get_address(
                client,
                "Bitcoin",
                parse_path("84'/0'/0'/0/0"),
                show_display=show_display,
                multisig=multisig,
                script_type=proto.InputScriptType.SPENDWITNESS,
            )
