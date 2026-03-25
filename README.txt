Repo
-------------------
git clone git@github.com:raumzeitt/rz-snn.git
cd rz-snn/

Git submodule notes
-------------------
cd rtl
git submodule add https://github.com/raumzeitt/rz-lib.git
git add ../.gitmodules rz-lib
git commit -m "..."

git submodule update --init --recursive

cd rz-lib
git fetch
git pull    
git add
git commit     
cd ..
git add rz-lib
git commit ...
