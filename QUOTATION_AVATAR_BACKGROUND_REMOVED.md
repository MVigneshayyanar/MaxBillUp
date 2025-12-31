# Quotation Customer Avatar - Background Circle Removed

## Change Made

Removed the CircleAvatar background wrapper from the customer selection section, keeping only the icon.

## Before

```dart
CircleAvatar(
    backgroundColor: (hasCustomer ? kPrimaryColor : kOrange).withValues(alpha: (0.1 * 255).toDouble()),
    radius: 18,
    child: Icon(hasCustomer ? Icons.person : Icons.person_add_outlined, 
         color: hasCustomer ? kPrimaryColor : kOrange, size: 18)
)
```

## After

```dart
Icon(hasCustomer ? Icons.person : Icons.person_add_outlined, 
     color: hasCustomer ? kPrimaryColor : kOrange, size: 24)
```

## Visual Changes

**Before:**
- Icon inside a circular background
- Background color: Light blue (10% opacity) when customer assigned, Light orange (10% opacity) when not assigned
- Icon size: 18
- Total visual size: ~36 (radius 18)

**After:**
- Just the icon, no background circle
- Icon color: Blue (kPrimaryColor) when customer assigned, Orange (kOrange) when not assigned
- Icon size: 24
- Cleaner, more minimal appearance

## Benefits

✅ **Cleaner UI**: No background circle clutter
✅ **More Minimal**: Follows modern design principles
✅ **Better Visibility**: Icon color stands out better without background
✅ **Consistent**: Icon size increased slightly to maintain visual presence

## Customer Selection Section Now Shows

- **No Customer Assigned**: Orange person_add icon (24px)
- **Customer Assigned**: Blue person icon (24px)

## Files Modified

- `lib/Sales/Quotation.dart` (Line ~385)

## Date
December 31, 2025

