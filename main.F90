program main

  use fox_dom

  implicit none

  character(len=12) :: filename
  type(Node), pointer :: ptr

  filename = 'settings.xml'
  ptr => parseFile(filename)
  call destroy(ptr)

end program main
