
# Copy all scheme files
#cp config/multitail/davit-*.conf /opt/davit/lib/multitail/

# Create composite (two options)
# Option A – include:
#cp config/multitail/davit-multitail.conf /opt/davit/lib/multitail/

# Option B – concatenate (more robust for some environments)
cat config/multitail/davit-base.conf \
    config/multitail/davit-*.conf \
    > /opt/davit/lib/multitail/davit-multitail.conf
