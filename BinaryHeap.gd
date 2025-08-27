extends RefCounted
class_name BinaryHeap

# ============================================================================
# BINARY HEAP PRIORITY QUEUE
# ============================================================================
# 
# Purpose: Efficient O(log n) priority queue for Dijkstra's algorithm
# 
# Core Responsibilities:
# - O(log n) insertion and extraction of minimum cost nodes
# - Maintains heap property: parent <= children
# - Supports pathfinding node structure: {region_id: int, cost: int}
# 
# Key Features:
# - Binary min-heap implementation
# - Efficient heapify operations
# - Memory-efficient array-based storage
# ============================================================================

# Heap storage: array of {region_id: int, cost: int}
var heap: Array = []

func size() -> int:
	"""Get the number of elements in the heap"""
	return heap.size()

func is_empty() -> bool:
	"""Check if the heap is empty"""
	return heap.is_empty()

func insert(item: Dictionary) -> void:
	"""Insert an item {region_id: int, cost: int} with O(log n) complexity"""
	heap.append(item)
	_heapify_up(heap.size() - 1)

func extract_min() -> Dictionary:
	"""Extract the minimum cost item with O(log n) complexity"""
	if heap.is_empty():
		return {}
	
	if heap.size() == 1:
		return heap.pop_back()
	
	# Store the minimum (root)
	var min_item = heap[0]
	
	# Move last element to root and remove last
	heap[0] = heap.pop_back()
	
	# Restore heap property
	_heapify_down(0)
	
	return min_item

func peek() -> Dictionary:
	"""Get the minimum item without removing it"""
	if heap.is_empty():
		return {}
	return heap[0]

func _heapify_up(index: int) -> void:
	"""Restore heap property by moving element up"""
	if index == 0:
		return
	
	var parent_index = (index - 1) / 2
	
	# If current item has lower cost than parent, swap and continue
	if heap[index].cost < heap[parent_index].cost:
		_swap(index, parent_index)
		_heapify_up(parent_index)

func _heapify_down(index: int) -> void:
	"""Restore heap property by moving element down"""
	var left_child = 2 * index + 1
	var right_child = 2 * index + 2
	var smallest = index
	
	# Find the smallest among parent and children
	if left_child < heap.size() and heap[left_child].cost < heap[smallest].cost:
		smallest = left_child
	
	if right_child < heap.size() and heap[right_child].cost < heap[smallest].cost:
		smallest = right_child
	
	# If smallest is not the parent, swap and continue
	if smallest != index:
		_swap(index, smallest)
		_heapify_down(smallest)

func _swap(i: int, j: int) -> void:
	"""Swap two elements in the heap"""
	var temp = heap[i]
	heap[i] = heap[j]
	heap[j] = temp

func clear() -> void:
	"""Clear all elements from the heap"""
	heap.clear()