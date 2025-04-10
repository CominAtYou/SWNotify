#pragma once
#include <stdint.h>
#include "types.h"

extern int tracked_count;
extern struct node* head;

void track_event(uint32_t wd, uint32_t cookie, const char* name);
int find_and_remove_event(uint32_t cookie, char* matched_name);
void remove_event(struct node* node);
