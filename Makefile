
genall:
	sh ./debian/genall.sh
	sh ./dtb/genall.sh

clean:
	rm -rf ./target_*
	sudo rm -rf 'dists'

update:
	sh ./update_all.sh


.PHONY: genall clean update

