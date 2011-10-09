if [ -f ~/.bashrc ]; then
   source ~/.bashrc
fi

# Setting PATH for EPD_free-7.1-2
# The orginal version is saved in .bash_profile.pysave
PATH="/Library/Frameworks/Python.framework/Versions/Current/bin:${PATH}"
export PATH
