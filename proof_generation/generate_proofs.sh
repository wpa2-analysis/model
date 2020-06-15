#!/usr/bin/env bash
# Run this script from the parent directory (i.e., the 'wpa2_model' directory)
echo === Building Tamarin Models Without Restrictions ===
echo 
make
echo
if ! [[ -e ./proof_generation/ut_tamarin/ut_tamarin ]]; then
	echo === Building UT Tamarin ===
	echo 
	cd ./proof_generation/ut_tamarin
	./build.sh
	cd ../..
	echo
fi
echo === Running Tamarin on Lemmas ===
echo 
tamarin_file="model/wpa2_four_way_handshake_patched.spthy"
ut_tamarin="./proof_generation/ut_tamarin/build/bin/uttamarin"
$ut_tamarin $tamarin_file --timeout=15000 --config_file=./proof_generation/utt_config.json --proof_directory=automatic_proofs ${@:1}
proof_generation/ku_proofs.sh
