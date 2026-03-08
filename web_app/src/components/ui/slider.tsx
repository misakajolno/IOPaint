import * as React from "react"
import * as SliderPrimitive from "@radix-ui/react-slider"

import { cn } from "@/lib/utils"

type SliderProps = React.ComponentPropsWithoutRef<typeof SliderPrimitive.Root> & {
  thumbClassName?: string
}

const Slider = React.forwardRef<
  React.ElementRef<typeof SliderPrimitive.Root>,
  SliderProps
>(({ className, thumbClassName, ...props }, ref) => (
  <SliderPrimitive.Root
    ref={ref}
    className={cn(
      "relative flex w-full touch-none select-none items-center",
      className
    )}
    tabIndex={-1}
    {...props}
  >
    <SliderPrimitive.Track className="relative h-1.5 w-full grow overflow-hidden rounded-full bg-primary/20 data-[disabled]:cursor-not-allowed data-[disabled]:opacity-50">
      <SliderPrimitive.Range className="absolute h-full bg-primary data-[disabled]:cursor-not-allowed " />
    </SliderPrimitive.Track>
    <SliderPrimitive.Thumb
      tabIndex={-1}
      className={cn(
        "block h-4 w-4 rounded-full border border-primary/60 bg-background shadow transition-colors focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-ring data-[disabled]:cursor-not-allowed",
        thumbClassName
      )}
    />
  </SliderPrimitive.Root>
))
Slider.displayName = SliderPrimitive.Root.displayName

export { Slider }
