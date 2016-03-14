use constant EXPERIMENT_ID_TYPE_UNKNOWN     => 0;
use constant EXPERIMENT_ID_TYPE_DB          => 1;
use constant EXPERIMENT_ID_TYPE_FF          => 2;

# Form selection values and default settings
use constant DFLT_TARGET_TAG_COUNT          => 10;
use constant DFLT_TARGET_TPM                => 1;
use constant DFLT_TARGET_RELATIVE_EXPRESSION    => 1;
use constant DFLT_BACKGROUND_TAG_COUNT      => 10;
use constant DFLT_BACKGROUND_TPM            => 1;
use constant DFLT_BACKGROUND_RELATIVE_EXPRESSION    => 1;


#
# The options from here to the end of the file are not used anymore
#

# The maximum number of target experiments/TSSs a user is allowed to
# paste/upload
use constant MAX_TARGET_EXPERIMENTS         => 100;
use constant MAX_BACKGROUND_EXPERIMENTS     => 1000;
# The maximum number of target experiments/TSSs a user is allowed to
# paste/upload
use constant MAX_TARGET_EXPERIMENTS         => 100;
use constant MAX_BACKGROUND_EXPERIMENTS     => 1000;

use constant DFLT_BG_NUM_RAND_EXPERIMENTS   => 1000;

1;
