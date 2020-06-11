#!/usr/bin/env bash
# Run this script from the parent directory (i.e., the 'wpa2_model' directory)
echo === Building Tamarin Models Without Restrictions ===
echo 
make
echo
if ! [[ -e ./proof_generation/ut_tamarin/ut_tamarin ]]; then
	echo === Building UT Tamarin ===
	echo 
	make -C ./proof_generation/ut_tamarin/
	echo
fi
echo === Running Tamarin on Lemmas ===
echo 
tamarin_file="wpa2_four_way_handshake.spthy"
ut_tamarin="./proof_generation/ut_tamarin/ut_tamarin"
$ut_tamarin $tamarin_file --timeout=15000 --config_file=./proof_generation/utt_config.json --proof_directory=automatic_proofs ${@:1}
proof_generation/ku_proofs.sh
