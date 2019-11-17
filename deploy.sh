#!/bin/bash

version=$(git rev-list --no-merges --count HEAD)

cat > scripting/include/gmx_version.inc <<EOT
#if defined _gmx_version_included
	#endinput
#endif

#define _gmx_version_included

#define GMX_MAJOR_VERSION			0
#define GMX_MINOR_VERSION			1
#define GMX_MAINTENANCE_VERSION		$version
#define GMX_VERSION_STR				"0.1.$version"
EOT

zip -9 -r -q --exclude=".git/*" --exclude=".gitignore" --exclude=".gitkeep" --exclude=".travis.yml" --exclude="README.md" --exclude="deploy.sh" gmx-amxx.zip .
