#include "util.h"
#include <sys/time.h>
#include <stdlib.h>

long long get_current_time_millis() {
    struct timeval tv;
    gettimeofday(&tv, NULL);
    return (long long) tv.tv_sec * 1000 + tv.tv_usec / 1000;
}
